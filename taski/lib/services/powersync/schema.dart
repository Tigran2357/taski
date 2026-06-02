import 'package:powersync/powersync.dart';

/// Local SQLite schema, mirrored from the Supabase Postgres tables.
/// Generated/confirmed by the PowerSync dashboard from the live tables.
///
/// Notes:
///  - PowerSync gives every table an implicit `id TEXT` primary key, so `id` is
///    not declared here.
///  - SQLite has no boolean/timestamp types: booleans are stored as INTEGER
///    (0/1) and timestamps as TEXT (ISO-8601).
///  - `archived_at` still exists on the Postgres `tasks` table (leftover column)
///    so it's included to match; the app does not use it.
final schema = Schema([
  Table('tasks', [
    Column.text('folder_id'),
    Column.text('title'),
    Column.integer('completed'),
    Column.text('created_at'),
    Column.text('user_id'),
    Column.text('color'),
    Column.text('timer_start'),
    Column.text('timer_end'),
    Column.integer('timer_total_seconds'),
    Column.integer('timer_paused'),
    Column.integer('timer_remaining_seconds'),
    Column.text('archived_at'),
    Column.text('completed_at'),
  ]),
  Table('folders', [
    Column.text('name'),
    Column.text('created_at'),
    Column.text('user_id'),
    Column.text('color'),
  ]),
]);
