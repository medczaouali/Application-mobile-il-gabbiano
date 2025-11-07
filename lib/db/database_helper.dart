import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ilgabbiano/models/cart_item.dart';
import 'package:ilgabbiano/models/complaint.dart';
import 'package:ilgabbiano/models/feedbacks.dart' as model;
import 'package:ilgabbiano/models/menu_item.dart';
import 'package:ilgabbiano/models/order.dart';
import 'package:ilgabbiano/models/reservation.dart';
import 'package:ilgabbiano/models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;
  // Cache whether complaint_messages has `is_read` to avoid PRAGMA calls on every query
  bool _complaintMessagesHasIsRead = false;
  bool _complaintMessagesHasIsReadChecked = false;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'ilgabbiano.db');
    return await openDatabase(
      path,
      version: 6, // Increment to add is_read for complaint messages
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Ensure DB schema compatibility when opening existing DBs
      onOpen: (Database db) async {
        await _ensureComplaintMessagesHasIsRead(db);
        // Also defensively ensure legacy DBs have the expected columns
        // on the complaints table (created_at, updated_at, type), since
        // some installs may have skipped migrations and would otherwise
        // crash on INSERT/SELECT statements referencing these columns.
        await _ensureComplaintsColumns(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        address_lat REAL,
        address_lng REAL,
        role TEXT NOT NULL DEFAULT 'client',
        profile_image TEXT,
        isBanned INTEGER DEFAULT 0
      )
    ''');

    // Add default admin user
    var bytes = utf8.encode('admin'); // password
    var digest = sha256.convert(bytes);
    await db.insert('users', {
      'name': 'Admin',
      'email': 'admin@admin.com',
      'password': digest.toString(),
      'phone': '0000000000',
      'role': 'admin',
      'isBanned': 0,
    });

    await db.execute('''
      CREATE TABLE menu(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        category TEXT NOT NULL,
        image_path TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE reservations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        guests INTEGER NOT NULL,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE feedbacks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        rating INTEGER NOT NULL,
        comment TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE complaints(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        type TEXT NOT NULL DEFAULT 'general',
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        items TEXT NOT NULL,
        total REAL NOT NULL,
        pickup_time TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'en attente',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE cart(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES menu(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE complaint_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        complaint_id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT DEFAULT (datetime('now')),
        is_read INTEGER DEFAULT 0,
        FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // This is a simple migration. For complex cases, you might need to copy data.
      try {
        await db.execute("ALTER TABLE users ADD COLUMN phone TEXT NOT NULL DEFAULT ''");
      } catch (e) { /* column might already exist */ }
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN total REAL NOT NULL DEFAULT 0");
      } catch (e) { /* column might already exist */ }
      
      await db.execute("DROP TABLE IF EXISTS cart");
      await db.execute('''
        CREATE TABLE cart(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES menu(id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute("DROP TABLE IF EXISTS feedback");
      await db.execute("DROP TABLE IF EXISTS feedbacks");
      await db.execute('''
        CREATE TABLE feedbacks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL UNIQUE,
          rating INTEGER NOT NULL,
          comment TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE users ADD COLUMN address TEXT DEFAULT ''");
      } catch (e) {
        // ignore if column exists
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE users ADD COLUMN address_lat REAL");
      } catch (e) {
        // Column may already exist; safe to ignore.
      }
      try {
        await db.execute("ALTER TABLE users ADD COLUMN address_lng REAL");
      } catch (e) {
        // Column may already exist; safe to ignore.
      }
    }
    // Ensure complaints table has timestamp columns (created_at, updated_at)
    try {
      await db.execute("ALTER TABLE complaints ADD COLUMN created_at TEXT");
    } catch (e) {
      // ignore if already exists
    }
    try {
      await db.execute("ALTER TABLE complaints ADD COLUMN updated_at TEXT");
    } catch (e) {
      // ignore if already exists
    }
    // Ensure complaints table has type column
    try {
      await db.execute("ALTER TABLE complaints ADD COLUMN type TEXT DEFAULT 'general'");
    } catch (e) {
      // ignore if already exists
    }
    // Ensure complaint_messages has is_read column
    try {
      await db.execute("ALTER TABLE complaint_messages ADD COLUMN is_read INTEGER DEFAULT 0");
    } catch (e) {
      // ignore if already exists
    }

    // Ensure complaint_messages table exists (for older DBs that may lack it)
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS complaint_messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          complaint_id INTEGER NOT NULL,
          sender_id INTEGER NOT NULL,
          message TEXT NOT NULL,
          created_at TEXT DEFAULT (datetime('now')),
          is_read INTEGER DEFAULT 0,
          FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
          FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
    } catch (e) {
      // ignore failures
    }
  }

  /// Ensure the complaint_messages table has the `is_read` column.
  /// Some older databases may have been created without this column; when
  /// opening the DB we attempt to add it if missing so queries that reference
  /// it won't fail.
  Future<void> _ensureComplaintMessagesHasIsRead(Database db) async {
    try {
      final cols = await db.rawQuery("PRAGMA table_info('complaint_messages')");
      final hasIsRead = cols.any((c) => c['name'] == 'is_read');
      if (!hasIsRead) {
        try {
          await db.execute("ALTER TABLE complaint_messages ADD COLUMN is_read INTEGER DEFAULT 0");
          _complaintMessagesHasIsRead = true;
        } catch (e) {
          // If ALTER fails for any reason, ignore — callers will use defensive queries.
          _complaintMessagesHasIsRead = false;
        }
      } else {
        _complaintMessagesHasIsRead = true;
      }
      _complaintMessagesHasIsReadChecked = true;
    } catch (e) {
      // If PRAGMA fails (table might not exist), attempt to create the table if missing.
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS complaint_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            complaint_id INTEGER NOT NULL,
            sender_id INTEGER NOT NULL,
            message TEXT NOT NULL,
            created_at TEXT DEFAULT (datetime('now')),
            is_read INTEGER DEFAULT 0,
            FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
            FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
          )
        ''');
      } catch (e) {
        // ignore
      }
    }
  }

  /// Ensure the complaints table has expected columns even if migrations
  /// were skipped on some devices. We add the columns if missing.
  Future<void> _ensureComplaintsColumns(Database db) async {
    try {
      final cols = await db.rawQuery("PRAGMA table_info('complaints')");
      bool hasCreatedAt = cols.any((c) => c['name'] == 'created_at');
      bool hasUpdatedAt = cols.any((c) => c['name'] == 'updated_at');
      bool hasType = cols.any((c) => c['name'] == 'type');

      if (!hasCreatedAt) {
        try { await db.execute("ALTER TABLE complaints ADD COLUMN created_at TEXT"); } catch (_) {}
      }
      if (!hasUpdatedAt) {
        try { await db.execute("ALTER TABLE complaints ADD COLUMN updated_at TEXT"); } catch (_) {}
      }
      if (!hasType) {
        try { await db.execute("ALTER TABLE complaints ADD COLUMN type TEXT DEFAULT 'general'"); } catch (_) {}
      }
    } catch (e) {
      // If PRAGMA fails, there's not much we can do here.
    }
  }

  /// Public helper to ensure complaint_messages schema is ready.
  /// This wraps the internal helper and can be safely called from other
  /// modules before starting services that query `is_read`.
  Future<void> ensureComplaintMessagesSchema() async {
    final db = await database;
    await _ensureComplaintMessagesHasIsRead(db);
  }

  /// Returns whether we've detected the `is_read` column on open. This may
  /// be false until `ensureComplaintMessagesSchema()` has run at least once.
  bool get complaintMessagesHasIsRead => _complaintMessagesHasIsReadChecked && _complaintMessagesHasIsRead;

  // User CRUD
  Future<int> registerUser(User user) async {
    final db = await database;
    var bytes = utf8.encode(user.password);
    var digest = sha256.convert(bytes);
    user.password = digest.toString();
    return await db.insert('users', user.toMap());
  }

  Future<User?> loginUser(String email, String password) async {
    final db = await database;
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    var result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, digest.toString()],
    );
    if (result.isNotEmpty) {
      final user = User.fromMap(result.first);
      if (user.isBanned == 1) {
        return null; // Banned user
      }
      return user;
    }
    return null;
  }

  Future<int> updateUserProfile(int id, String name, String email, String phone, String address, double? lat, double? lng, String? imagePath) async {
    final db = await database;
    Map<String, dynamic> data = {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'address_lat': lat,
      'address_lng': lng,
    };
    if (imagePath != null) {
      data['profile_image'] = imagePath;
    }
    return await db.update('users', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateUserRole(int id, String role) async {
    final db = await database;
    return await db.update('users', {'role': role}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updatePassword(String email, String newPassword) async {
    final db = await database;
    var bytes = utf8.encode(newPassword);
    var digest = sha256.convert(bytes);
    return await db.update('users', {'password': digest.toString()}, where: 'email = ?', whereArgs: [email]);
  }

  Future<int> updatePasswordById(int id, String newPassword) async {
    final db = await database;
    var bytes = utf8.encode(newPassword);
    var digest = sha256.convert(bytes);
    return await db.update('users', {'password': digest.toString()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    var result = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    var result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    var result = await db.query('users');
    return result.map((e) => User.fromMap(e)).toList();
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<int> banUser(int id, bool isBanned) async {
    final db = await database;
    return await db.update('users', {'isBanned': isBanned ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  // Menu CRUD
  Future<int> createMenuItem(MenuItem item) async {
    final db = await database;
    return await db.insert('menu', item.toMap());
  }

  Future<List<MenuItem>> getMenu() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('menu');
    return List.generate(maps.length, (i) {
      return MenuItem.fromMap(maps[i]);
    });
  }

  Future<int> updateMenuItem(MenuItem item) async {
    final db = await database;
    return await db.update('menu', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteMenuItem(int id) async {
    final db = await database;
    return await db.delete('menu', where: 'id = ?', whereArgs: [id]);
  }

  // Cart CRUD
  Future<void> addToCart(CartItem item) async {
    final db = await database;
    final existingItems = await db.query(
      'cart',
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [item.userId, item.productId],
    );

    if (existingItems.isNotEmpty) {
      int newQuantity = (existingItems.first['quantity'] as int) + item.quantity;
      await db.update(
        'cart',
        {'quantity': newQuantity},
        where: 'id = ?',
        whereArgs: [existingItems.first['id']],
      );
    } else {
      await db.insert('cart', item.toMap());
    }
  }

  Future<void> removeFromCart(int cartItemId) async {
    final db = await database;
    await db.delete('cart', where: 'id = ?', whereArgs: [cartItemId]);
  }

  Future<void> updateCartItemQuantity(int cartItemId, int quantity) async {
    final db = await database;
    if (quantity > 0) {
      await db.update('cart', {'quantity': quantity}, where: 'id = ?', whereArgs: [cartItemId]);
    } else {
      await removeFromCart(cartItemId);
    }
  }

  Future<List<CartItem>> getCartItems(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.id, c.user_id, c.product_id, c.quantity,
             m.name, m.description, m.price, m.category, m.image_path
      FROM cart c
      JOIN menu m ON c.product_id = m.id
      WHERE c.user_id = ?
    ''', [userId]);

    return List.generate(maps.length, (i) {
      final map = maps[i];
      final menuItem = MenuItem(
        id: map['product_id'] as int,
        name: map['name'] as String,
        description: map['description'] as String,
        price: map['price'] as double,
        category: map['category'] as String,
        imagePath: map['image_path'] as String?,
      );
      return CartItem(
        id: map['id'] as int,
        userId: map['user_id'] as int,
        productId: map['product_id'] as int,
        quantity: map['quantity'] as int,
        menuItem: menuItem,
      );
    });
  }

  Future<void> clearCart(int userId) async {
    final db = await database;
    await db.delete('cart', where: 'user_id = ?', whereArgs: [userId]);
  }

  // Order CRUD
  Future<int> createOrder(Order order) async {
    final db = await database;
    return await db.insert('orders', order.toMap());
  }

  Future<List<Order>> getOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('orders', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => Order.fromMap(maps[i]));
  }

  Future<List<Order>> getOrdersByUser(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => Order.fromMap(maps[i]));
  }

  Future<int> updateOrderStatus(int id, String status) async {
    final db = await database;
    return await db.update('orders', {'status': status}, where: 'id = ?', whereArgs: [id]);
  }

  /// Count of new/incoming take-away orders (status = 'en attente')
  Future<int> countPendingOrders() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as c FROM orders WHERE status = ?", ['en attente']);
    final count = result.isNotEmpty ? (result.first['c'] as int) : 0;
    return count;
  }

  // Reservation CRUD
  Future<int> createReservation(Reservation reservation) async {
    final db = await database;
    return await db.insert('reservations', reservation.toMap());
  }

  /// Admin view: reservations joined with users to get name and profile image
  Future<List<Map<String, dynamic>>> getReservationsWithUsers() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.id, r.user_id, r.date, r.time, r.guests, r.notes, r.status,
             u.name AS user_name, u.profile_image AS user_profile_image
      FROM reservations r
      JOIN users u ON r.user_id = u.id
      ORDER BY r.date DESC, r.time ASC
    ''');
    return rows;
  }

  Future<List<Reservation>> getReservations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reservations');
    return List.generate(maps.length, (i) {
      return Reservation.fromMap(maps[i]);
    });
  }

  Future<int> updateReservationStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'reservations',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count of new/incoming reservations (status = 'pending')
  Future<int> countPendingReservations() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as c FROM reservations WHERE status = ?", ['pending']);
    final count = result.isNotEmpty ? (result.first['c'] as int) : 0;
    return count;
  }

  /// Count of new/incoming complaints (status = 'pending')
  Future<int> countPendingComplaints() async {
    final db = await database;
    final result = await db.rawQuery("SELECT COUNT(*) as c FROM complaints WHERE status = ?", ['pending']);
    final count = result.isNotEmpty ? (result.first['c'] as int) : 0;
    return count;
  }

  Future<int> updateReservation(Reservation reservation) async {
    final db = await database;
    return await db.update('reservations', reservation.toMap(), where: 'id = ?', whereArgs: [reservation.id]);
  }

  Future<int> deleteReservation(int id) async {
    final db = await database;
    return await db.delete('reservations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Reservation>> getUserReservations(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reservations',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) {
      return Reservation.fromMap(maps[i]);
    });
  }

  // Feedback CRUD
  Future<void> createOrUpdateFeedback(model.Feedback feedback) async {
    final db = await database;
    final existing = await getFeedbackByUser(feedback.userId);
    if (existing != null) {
      // Do not include 'id' in the update map to avoid attempting to set PK to null
      final updateData = {
        'rating': feedback.rating,
        'comment': feedback.comment,
      };
      await db.update('feedbacks', updateData, where: 'user_id = ?', whereArgs: [feedback.userId]);
    } else {
      await db.insert('feedbacks', feedback.toMap());
    }
  }

  Future<model.Feedback?> getFeedbackByUser(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('feedbacks', where: 'user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) {
      return model.Feedback.fromMap(maps.first);
    }
    return null;
  }

  Future<List<model.Feedback>> getFeedback() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('feedbacks');
    return List.generate(maps.length, (i) {
      return model.Feedback.fromMap(maps[i]);
    });
  }

  /// Returns the global average rating and count of feedbacks.
  Future<Map<String, dynamic>> getFeedbackAverage() async {
    final db = await database;
    final res = await db.rawQuery('SELECT AVG(rating) AS avg_rating, COUNT(*) AS total FROM feedbacks');
    if (res.isNotEmpty) {
      final avg = (res.first['avg_rating'] as num?)?.toDouble() ?? 0.0;
      final total = (res.first['total'] as int?) ?? 0;
      return {'average': avg, 'count': total};
    }
    return {'average': 0.0, 'count': 0};
  }

  /// Returns feedbacks joined with user info for display in lists.
  Future<List<Map<String, dynamic>>> getFeedbacksWithUsers() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT f.id, f.user_id, f.rating, f.comment,
             u.name AS user_name, u.profile_image AS user_profile_image
      FROM feedbacks f
      JOIN users u ON f.user_id = u.id
      ORDER BY f.rating DESC, f.id DESC
    ''');
    return rows;
  }

  Future<int> deleteFeedback(int userId) async {
    final db = await database;
    return await db.delete('feedbacks', where: 'user_id = ?', whereArgs: [userId]);
  }

  // Complaint CRUD
  Future<int> createComplaint(Complaint complaint) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final data = complaint.toMap();
    data['created_at'] = data['created_at'] ?? now;
    data['updated_at'] = now;
    return await db.insert('complaints', data);
  }

  Future<List<Complaint>> getComplaints() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('complaints');
    return List.generate(maps.length, (i) {
      return Complaint.fromMap(maps[i]);
    });
  }

  Future<List<Complaint>> getComplaintsByUser(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'complaints',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) {
      return Complaint.fromMap(maps[i]);
    });
  }

  /// Returns complaints joined with the user who created them.
  /// Each map contains the complaint fields plus a `user_name` key.
  Future<List<Map<String, dynamic>>> getComplaintsWithUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.id, c.user_id, c.message, c.status, c.type, c.created_at, c.updated_at, u.name AS user_name, u.role AS user_role, u.profile_image AS user_profile_image
      FROM complaints c
      JOIN users u ON c.user_id = u.id
      ORDER BY c.id DESC
    ''');
    return maps;
  }

  Future<int> updateComplaint(Complaint complaint) async {
    final db = await database;
    final data = complaint.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('complaints', data, where: 'id = ?', whereArgs: [complaint.id]);
  }

  // Complaint messages (two-way conversation)
  Future<int> addComplaintMessage(int complaintId, int senderId, String message) async {
    final db = await database;
    // Insert without is_read to remain compatible with older DBs that lack the column
    return await db.insert('complaint_messages', {
      'complaint_id': complaintId,
      'sender_id': senderId,
      'message': message,
    });
  }

  Future<List<Map<String, dynamic>>> getComplaintMessages(int complaintId) async {
    final db = await database;
    // Use cached knowledge to avoid throwing queries referencing is_read.
    if (complaintMessagesHasIsRead) {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT m.id, m.complaint_id, m.sender_id, m.message, m.created_at, m.is_read, u.name AS sender_name, u.profile_image AS sender_profile_image
        FROM complaint_messages m
        JOIN users u ON m.sender_id = u.id
        WHERE m.complaint_id = ?
        ORDER BY m.created_at ASC
      ''', [complaintId]);
      return maps;
    } else {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT m.id, m.complaint_id, m.sender_id, m.message, m.created_at, u.name AS sender_name, u.profile_image AS sender_profile_image
        FROM complaint_messages m
        JOIN users u ON m.sender_id = u.id
        WHERE m.complaint_id = ?
        ORDER BY m.created_at ASC
      ''', [complaintId]);
      return maps.map((m) {
        final mm = Map<String, dynamic>.from(m);
        mm['is_read'] = 0;
        return mm;
      }).toList();
    }
  }

  /// Fetch messages in pages. If [beforeCreatedAt] is null, returns the latest [limit]
  /// messages (ascending). If [beforeCreatedAt] is provided, returns up to [limit]
  /// messages older than that timestamp.
  Future<List<Map<String, dynamic>>> getComplaintMessagesPaginated(int complaintId, {String? beforeCreatedAt, int limit = 20}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (complaintMessagesHasIsRead) {
      if (beforeCreatedAt == null) {
        maps = await db.rawQuery('''
          SELECT m.id, m.complaint_id, m.sender_id, m.message, m.created_at, m.is_read, u.name AS sender_name, u.profile_image AS sender_profile_image
          FROM complaint_messages m
          JOIN users u ON m.sender_id = u.id
          WHERE m.complaint_id = ?
          ORDER BY m.created_at DESC
          LIMIT ?
        ''', [complaintId, limit]);
      } else {
        maps = await db.rawQuery('''
          SELECT m.id, m.complaint_id, m.sender_id, m.message, m.created_at, m.is_read, u.name AS sender_name, u.profile_image AS sender_profile_image
          FROM complaint_messages m
          JOIN users u ON m.sender_id = u.id
          WHERE m.complaint_id = ? AND m.created_at < ?
          ORDER BY m.created_at DESC
          LIMIT ?
        ''', [complaintId, beforeCreatedAt, limit]);
      }
      return maps.reversed.toList();
    } else {
      if (beforeCreatedAt == null) {
        maps = await db.rawQuery('''
          SELECT m.id, m.complaint_id, m.sender_id, m.message, m.created_at, u.name AS sender_name, u.profile_image AS sender_profile_image
          FROM complaint_messages m
          JOIN users u ON m.sender_id = u.id
          WHERE m.complaint_id = ?
          ORDER BY m.created_at DESC
          LIMIT ?
        ''', [complaintId, limit]);
      } else {
        maps = await db.rawQuery('''
          SELECT m.id, m.complaint_id, m.sender_id, m.message, m.created_at, u.name AS sender_name, u.profile_image AS sender_profile_image
          FROM complaint_messages m
          JOIN users u ON m.sender_id = u.id
          WHERE m.complaint_id = ? AND m.created_at < ?
          ORDER BY m.created_at DESC
          LIMIT ?
        ''', [complaintId, beforeCreatedAt, limit]);
      }
      return maps.map((m) {
        final mm = Map<String, dynamic>.from(m);
        mm['is_read'] = 0;
        return mm;
      }).toList().reversed.toList();
    }
  }

  Future<int> getUnreadMessagesCount(int complaintId, int userId) async {
    final db = await database;
    // Use cached knowledge to avoid throwing SQL that references is_read
    if (complaintMessagesHasIsRead) {
      try {
        final res = await db.rawQuery('''
          SELECT COUNT(*) as cnt FROM complaint_messages
          WHERE complaint_id = ? AND sender_id != ? AND (is_read IS NULL OR is_read = 0)
        ''', [complaintId, userId]);
        return Sqflite.firstIntValue(res) ?? 0;
      } catch (e) {
        // If something unexpected happens, fallback to permissive count below
      }
    }
    // fallback permissive count
    try {
      final res = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM complaint_messages
        WHERE complaint_id = ? AND sender_id != ?
      ''', [complaintId, userId]);
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markComplaintMessagesRead(int complaintId, int readerId) async {
    final db = await database;
    // Ensure we've checked for the existence of the is_read column and attempt
    // to add it if missing. If after that the column is still missing, avoid
    // issuing an UPDATE that will log errors on older databases.
    if (!_complaintMessagesHasIsReadChecked) {
      try {
        await _ensureComplaintMessagesHasIsRead(db);
      } catch (e) {
        // ignore
      }
    }
    if (!complaintMessagesHasIsRead) {
      // Nothing to mark as read on this DB schema
      return;
    }
    try {
      // Mark messages as read where sender is not the reader
      await db.update('complaint_messages', {'is_read': 1}, where: 'complaint_id = ? AND sender_id != ?', whereArgs: [complaintId, readerId]);
    } catch (e) {
      // ignore failures - perhaps concurrent migration removed the column
    }
  }

  Future<int> deleteComplaint(int id) async {
    final db = await database;
    return await db.delete('complaints', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateComplaintStatus(int id, String status) async {
    final db = await database;
    return await db.update(
      'complaints',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
