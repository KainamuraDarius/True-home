import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('property_images.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE property_images (
        id TEXT PRIMARY KEY,
        property_id TEXT NOT NULL,
        image_data BLOB NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<String> insertImage({
    required String propertyId,
    required Uint8List imageData,
  }) async {
    final db = await database;
    final id = '${propertyId}_${DateTime.now().millisecondsSinceEpoch}';
    
    await db.insert(
      'property_images',
      {
        'id': id,
        'property_id': propertyId,
        'image_data': imageData,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  Future<List<Map<String, dynamic>>> getImagesForProperty(String propertyId) async {
    final db = await database;
    return await db.query(
      'property_images',
      where: 'property_id = ?',
      whereArgs: [propertyId],
    );
  }

  Future<Uint8List?> getImage(String imageId) async {
    final db = await database;
    final results = await db.query(
      'property_images',
      where: 'id = ?',
      whereArgs: [imageId],
    );

    if (results.isNotEmpty) {
      return results.first['image_data'] as Uint8List;
    }
    return null;
  }

  Future<void> deleteImage(String imageId) async {
    final db = await database;
    await db.delete(
      'property_images',
      where: 'id = ?',
      whereArgs: [imageId],
    );
  }

  Future<void> deleteAllImagesForProperty(String propertyId) async {
    final db = await database;
    await db.delete(
      'property_images',
      where: 'property_id = ?',
      whereArgs: [propertyId],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
