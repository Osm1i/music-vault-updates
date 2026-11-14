#!/usr/bin/env python3
from pathlib import Path
import sqlite3
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "payload"))
from remove_v98_owner_profile import remove_v98_owner_profile

def fixture(path, owner_created=30, owner_has_data=False):
    c=sqlite3.connect(path)
    c.executescript("""
      CREATE TABLE family_members(id INTEGER PRIMARY KEY,name TEXT UNIQUE,color TEXT,created REAL);
      CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT);
      CREATE TABLE user_accounts(id INTEGER PRIMARY KEY,username TEXT,member TEXT,password_hash TEXT);
      CREATE TABLE tracks(id INTEGER PRIMARY KEY,title TEXT);
      CREATE TABLE profile_library(member TEXT,track_id INTEGER,added REAL,source TEXT);
      CREATE TABLE personal_favorites(member TEXT,track_id INTEGER,added REAL);
      CREATE TABLE personal_history(member TEXT,track_id INTEGER,played REAL);
      CREATE TABLE personal_playlists(id INTEGER PRIMARY KEY,member TEXT,name TEXT);
      CREATE TABLE profile_preferences(member TEXT PRIMARY KEY,avatar TEXT);
      CREATE TABLE apple_library_tracks(id INTEGER PRIMARY KEY,member TEXT);
      CREATE TABLE apple_library_playlists(id INTEGER PRIMARY KEY,member TEXT);
      CREATE TRIGGER mv98_admin_track_membership AFTER INSERT ON tracks BEGIN SELECT 1; END;
      INSERT INTO family_members VALUES(1,'Maya','#aaa',10);
      INSERT INTO family_members VALUES(2,'Jordan','#bbb',20);
      INSERT INTO family_members VALUES(3,'Owner','#ccc',30);
      INSERT INTO settings VALUES('profile_library_migrated_v1','1');
      INSERT INTO settings VALUES('active_member','Maya');
      INSERT INTO user_accounts VALUES(1,'owneruser','Owner','fake-hash');
      INSERT INTO tracks VALUES(1,'Existing track');
      INSERT INTO profile_library VALUES('Owner',1,30,'legacy-owner');
      INSERT INTO profile_preferences VALUES('Owner','O');
    """)
    if owner_has_data:
        c.execute("INSERT INTO personal_favorites VALUES('Owner',1,33)")
    c.commit();c.close()

def main():
    with tempfile.TemporaryDirectory() as td:
        db=Path(td)/"musicvault.db"
        fixture(db)
        result=remove_v98_owner_profile(db)
        assert result["removed"]=="Owner"
        assert result["remaining"]==["Maya","Jordan"]
        c=sqlite3.connect(db)
        assert c.execute("SELECT COUNT(*) FROM family_members").fetchone()[0]==2
        assert c.execute("SELECT COUNT(*) FROM tracks").fetchone()[0]==1
        assert c.execute("SELECT COUNT(*) FROM personal_favorites").fetchone()[0]==0
        assert c.execute("SELECT COUNT(*) FROM profile_preferences WHERE member='Owner'").fetchone()[0]==0
        tables={r[0] for r in c.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert "user_accounts" not in tables and "profile_library" not in tables
        assert c.execute("SELECT value FROM settings WHERE key='active_member'").fetchone()[0]=="Maya"
        assert c.execute("SELECT value FROM settings WHERE key='profile_library_migrated_v1'").fetchone() is None
        c.close()

        db2=Path(td)/"must-not-delete.db"
        fixture(db2, owner_has_data=True)
        try:
            remove_v98_owner_profile(db2)
            raise AssertionError("Expected cleanup to refuse deleting a profile containing personal data.")
        except RuntimeError as e:
            assert "personal data" in str(e)
        c=sqlite3.connect(db2)
        assert c.execute("SELECT COUNT(*) FROM family_members WHERE name='Owner'").fetchone()[0]==1
        assert c.execute("SELECT COUNT(*) FROM user_accounts").fetchone()[0]==1
        c.close()

        db3=Path(td)/"old-owner.db"
        fixture(db3, owner_created=5)
        c=sqlite3.connect(db3)
        c.execute("UPDATE family_members SET created=5 WHERE name='Owner'")
        c.commit();c.close()
        try:
            remove_v98_owner_profile(db3)
            raise AssertionError("Expected cleanup to refuse removing an older Owner profile.")
        except RuntimeError as e:
            assert "newer" in str(e)
        c=sqlite3.connect(db3)
        assert c.execute("SELECT COUNT(*) FROM family_members WHERE name='Owner'").fetchone()[0]==1
        c.close()
    print("PASS: only a clearly synthetic 9.8 Owner profile is removed; original profile and music data remain.")

if __name__=="__main__":
    main()
