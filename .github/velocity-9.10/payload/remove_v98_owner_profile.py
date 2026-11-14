#!/usr/bin/env python3
"""Remove only the synthetic Owner profile and v9.8-only account storage."""
from __future__ import annotations
import sqlite3
import sys
from pathlib import Path

OWNER = "Owner"
AUTH_TABLES = ("user_accounts", "profile_library")
PERSONAL_TABLES = (
    ("personal_playlists", "member"),
    ("personal_favorites", "member"),
    ("personal_history", "member"),
    ("profile_preferences", "member"),
    ("apple_library_tracks", "member"),
    ("apple_library_playlists", "member"),
)

def _tables(conn):
    return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}

def _columns(conn, table):
    return {r[1] for r in conn.execute(f'PRAGMA table_info("{table}")')}

def remove_v98_owner_profile(db_path: str | Path) -> dict:
    path = Path(db_path)
    if not path.is_file():
        raise RuntimeError(f"Music Vault database not found: {path}")
    conn = sqlite3.connect(path, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA foreign_keys=ON")
        conn.execute("BEGIN IMMEDIATE")
        tables = _tables(conn)
        if "family_members" not in tables or "settings" not in tables:
            raise RuntimeError("Expected legacy Music Vault profile tables are missing; no cleanup performed.")

        owners = conn.execute(
            "SELECT id,name,created FROM family_members WHERE lower(name)=lower(?)", (OWNER,)
        ).fetchall()
        if len(owners) > 1:
            raise RuntimeError("Multiple Owner profiles found; refusing ambiguous cleanup.")

        other_profiles = conn.execute(
            "SELECT id,name,created FROM family_members WHERE lower(name)<>lower(?) ORDER BY created,id",
            (OWNER,),
        ).fetchall()
        if len(other_profiles) != 2:
            raise RuntimeError(
                f"Expected exactly two original profiles alongside the extra Owner profile; "
                f"found {len(other_profiles)} other profiles. No profile was removed."
            )

        marker = conn.execute(
            "SELECT value FROM settings WHERE key='profile_library_migrated_v1'"
        ).fetchone()
        if marker is None or str(marker["value"]) != "1":
            raise RuntimeError("The 9.8 profile-migration marker is missing; refusing to guess which Owner profile to remove.")

        missing = [t for t in AUTH_TABLES if t not in tables]
        if missing:
            raise RuntimeError("The expected 9.8-only account tables are missing: " + ", ".join(missing))

        removed_name = None
        if owners:
            owner = owners[0]
            try:
                owner_created = float(owner["created"])
                other_created = [float(r["created"]) for r in other_profiles]
            except (TypeError, ValueError):
                raise RuntimeError("Profile creation timestamps are invalid; refusing to remove Owner.")
            if not other_created or owner_created <= max(other_created):
                raise RuntimeError(
                    "Owner is not demonstrably newer than both original profiles; "
                    "refusing to remove a potentially real family profile."
                )

            # The 9.8 migration creates profile_library rows but does not populate
            # the legacy personal-data tables for a newly-created Owner row.
            # Keep the profile if any such legacy data is attached to it.
            references = {}
            for table, column in PERSONAL_TABLES:
                if table in tables and column in _columns(conn, table):
                    count = int(conn.execute(
                        f'SELECT COUNT(*) FROM "{table}" WHERE lower("{column}")=lower(?)',
                        (owner["name"],),
                    ).fetchone()[0])
                    if count:
                        references[table] = count
            if references:
                summary = ", ".join(f"{k}={v}" for k, v in sorted(references.items()))
                raise RuntimeError(
                    "The Owner entry contains personal data (" + summary +
                    "); refusing to remove or merge it automatically."
                )

            conn.execute("DELETE FROM family_members WHERE id=?", (owner["id"],))
            removed_name = str(owner["name"])

        conn.execute("DROP TRIGGER IF EXISTS mv98_admin_track_membership")
        # These tables and this marker were introduced exclusively by 9.8.
        # The classic Music Vault uses the original shared tracks/profile tables.
        conn.execute("DROP TABLE IF EXISTS profile_library")
        conn.execute("DROP TABLE IF EXISTS user_accounts")
        conn.execute("DELETE FROM settings WHERE key='profile_library_migrated_v1'")

        # Do not leave a stale active profile pointer if it pointed at the
        # generated Owner row. Fall back to the oldest original family profile.
        active = conn.execute("SELECT value FROM settings WHERE key='active_member'").fetchone()
        if active and removed_name and str(active["value"]).casefold() == removed_name.casefold():
            fallback = str(other_profiles[0]["name"])
            conn.execute("UPDATE settings SET value=? WHERE key='active_member'", (fallback,))

        remaining = conn.execute("SELECT name FROM family_members ORDER BY created,id").fetchall()
        names = [str(r["name"]) for r in remaining]
        if len(names) != 2 or any(n.casefold() == "owner" for n in names):
            raise RuntimeError("Post-cleanup profile validation failed; transaction will be rolled back.")

        conn.commit()
        return {"removed": removed_name, "remaining": names, "auth_tables_removed": True}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: remove_v98_owner_profile.py /path/to/musicvault.db")
    result = remove_v98_owner_profile(sys.argv[1])
    print("PASS: removed only the synthetic 9.8 Owner profile and retired its account-only tables.")
    print("Remaining profiles: " + " | ".join(result["remaining"]))
    print("Legacy playlists, favorites, history, tracks, and audio paths were not modified.")

if __name__ == "__main__":
    main()
