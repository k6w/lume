import Foundation
import GRDB

enum Migrations {
    static func register() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        // Foreign keys / WAL / etc. are configured by GRDB's defaults.

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE clip (
                  id            TEXT PRIMARY KEY,
                  contentHash   TEXT NOT NULL UNIQUE,
                  kind          INTEGER NOT NULL,
                  plainText     TEXT,
                  rtfData       BLOB,
                  htmlData      BLOB,
                  imageData     BLOB,
                  thumbnailData BLOB,
                  fileURLs      TEXT,
                  colorHex      TEXT,
                  detectedLanguage TEXT,
                  sourceBundleID   TEXT,
                  byteSize      INTEGER NOT NULL,
                  isPinned      INTEGER NOT NULL DEFAULT 0,
                  isEncrypted   INTEGER NOT NULL DEFAULT 0,
                  encryptedBlob BLOB,
                  createdAt     REAL NOT NULL,
                  lastSeenAt    REAL NOT NULL,
                  hitCount      INTEGER NOT NULL DEFAULT 1
                );
                CREATE INDEX idx_clip_lastSeen ON clip(isPinned DESC, lastSeenAt DESC);
                CREATE INDEX idx_clip_source   ON clip(sourceBundleID);
            """)

            try db.execute(sql: """
                CREATE VIRTUAL TABLE clip_fts USING fts5(
                  plainText, sourceBundleID,
                  content='clip', content_rowid='rowid',
                  tokenize='unicode61 remove_diacritics 2'
                );
            """)

            // FTS triggers — only synchronize when textual columns matter.
            try db.execute(sql: """
                CREATE TRIGGER clip_ai AFTER INSERT ON clip BEGIN
                  INSERT INTO clip_fts(rowid, plainText, sourceBundleID)
                  VALUES (new.rowid, new.plainText, new.sourceBundleID);
                END;
                CREATE TRIGGER clip_ad AFTER DELETE ON clip BEGIN
                  INSERT INTO clip_fts(clip_fts, rowid, plainText, sourceBundleID)
                  VALUES ('delete', old.rowid, old.plainText, old.sourceBundleID);
                END;
                CREATE TRIGGER clip_au AFTER UPDATE OF plainText, sourceBundleID ON clip BEGIN
                  INSERT INTO clip_fts(clip_fts, rowid, plainText, sourceBundleID)
                  VALUES ('delete', old.rowid, old.plainText, old.sourceBundleID);
                  INSERT INTO clip_fts(rowid, plainText, sourceBundleID)
                  VALUES (new.rowid, new.plainText, new.sourceBundleID);
                END;
            """)

            try db.execute(sql: """
                CREATE TABLE tag (
                  id       TEXT PRIMARY KEY,
                  name     TEXT NOT NULL UNIQUE,
                  colorHex TEXT
                );
                CREATE TABLE clip_tag (
                  clipID TEXT NOT NULL,
                  tagID  TEXT NOT NULL,
                  PRIMARY KEY (clipID, tagID),
                  FOREIGN KEY (clipID) REFERENCES clip(id) ON DELETE CASCADE,
                  FOREIGN KEY (tagID)  REFERENCES tag(id)  ON DELETE CASCADE
                );
                CREATE TABLE snippet (
                  id        TEXT PRIMARY KEY,
                  title     TEXT NOT NULL,
                  body      TEXT NOT NULL,
                  shortcut  TEXT,
                  kind      INTEGER NOT NULL,
                  updatedAt REAL NOT NULL
                );
                CREATE TABLE rule (
                  id       TEXT PRIMARY KEY,
                  name     TEXT NOT NULL,
                  regex    TEXT NOT NULL,
                  action   TEXT NOT NULL,
                  enabled  INTEGER NOT NULL DEFAULT 1,
                  priority INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE excluded_app (
                  bundleID TEXT PRIMARY KEY,
                  addedAt  REAL NOT NULL
                );
                CREATE TABLE meta (
                  key   TEXT PRIMARY KEY,
                  value TEXT
                );
                CREATE TABLE sync_state (
                  clipID            TEXT PRIMARY KEY,
                  ckRecordName      TEXT,
                  ckRecordChangeTag TEXT,
                  pendingOp         INTEGER NOT NULL DEFAULT 0,
                  lastSyncedAt      REAL
                );
                CREATE INDEX idx_sync_pending ON sync_state(pendingOp) WHERE pendingOp != 0;
            """)
        }

        return migrator
    }
}
