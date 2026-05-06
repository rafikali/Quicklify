import '../local/database_helper.dart';
import '../../features/downloads/models/download_item.dart';

class DownloadDao {
  DownloadDao._();

  static Future<void> insert(DownloadItem item) async {
    final db = await DatabaseHelper.database;
    await db.insert('downloads', item.toMap());
  }

  static Future<List<DownloadItem>> getAll() async {
    final db = await DatabaseHelper.database;
    final maps = await db.query('downloads', orderBy: 'created_at DESC');
    return maps.map((map) => DownloadItem.fromMap(map)).toList();
  }

  static Future<void> updateStatus(String id, int status, int progress) async {
    final db = await DatabaseHelper.database;
    final updates = <String, dynamic>{
      'status': status,
      'progress': progress,
    };
    if (status == 2) {
      updates['completed_at'] = DateTime.now().millisecondsSinceEpoch;
    }
    await db.update('downloads', updates, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateTaskId(String id, String taskId) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'downloads',
      {'task_id': taskId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> delete(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteAll() async {
    final db = await DatabaseHelper.database;
    await db.delete('downloads');
  }

  static Future<DownloadItem?> getByTaskId(String taskId) async {
    final db = await DatabaseHelper.database;
    final maps = await db.query(
      'downloads',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    if (maps.isEmpty) return null;
    return DownloadItem.fromMap(maps.first);
  }
}
