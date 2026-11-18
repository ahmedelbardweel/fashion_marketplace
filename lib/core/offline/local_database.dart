import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

import '../../core/filtering/filter_models.dart';
import '../../core/pagination/paginated_state.dart';
import '../../features/admin/domain/models/admin_stats.dart';
import '../../features/admin/domain/models/catalog_models.dart';
import '../../features/auth/domain/models/app_user.dart';
import '../../features/customer/domain/models/cart_item.dart';
import '../../features/customer/domain/models/customer_order.dart';
import '../../features/customer/domain/models/customer_product.dart'
    as customer_models;
import '../../features/customer/domain/models/customer_shop.dart';
import '../../features/shop/domain/models/shop.dart';
import '../../features/shop/domain/models/shop_product.dart' as shop_models;
import 'offline_security_service.dart';

class SyncOutboxRecord {
  const SyncOutboxRecord({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.entityId,
    required this.payload,
    required this.encryptedPayload,
    required this.hmacSignature,
    required this.status,
    required this.retryCount,
    required this.createdAtMs,
    this.lastError,
  });

  final String id;
  final String userId;
  final String actionType;
  final String entityId;
  final Map<String, dynamic> payload;
  final String encryptedPayload;
  final String hmacSignature;
  final String status;
  final int retryCount;
  final int createdAtMs;
  final String? lastError;
}

/// Local SQLite relational database mirroring all Supabase tables
/// with AES-256-GCM encryption for sensitive user/order/cart records
/// and HMAC-SHA256 integrity protection for the offline sync outbox.
class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const String _dbFileName = 'shopy_offline_vault_v1.db';
  static const int _dbVersion = 1;

  Database? _db;
  final Lock _initLock = Lock();
  final Lock _writeLock = Lock();

  bool get isReady => _db != null;

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_db != null) return _db;
    return _initLock.synchronized(() async {
      if (_db != null) return _db;
      try {
        await OfflineSecurityService.instance.initialize();
        final dbRoot = await getDatabasesPath();
        final fullPath = p.join(dbRoot, _dbFileName);
        _db = await openDatabase(
          fullPath,
          version: _dbVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = OFF');
          },
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
        return _db;
      } catch (e) {
        debugPrint('[LocalDatabase] Failed to open SQLite database: $e');
        return null;
      }
    });
  }

  Future<void> initialize() async {
    await OfflineSecurityService.instance.initialize();
    await database;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. profiles (sensitive fields encrypted in encrypted_blob)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        full_name TEXT,
        phone TEXT,
        city TEXT,
        address TEXT,
        role TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        profile_completed INTEGER NOT NULL DEFAULT 0,
        is_current_session INTEGER NOT NULL DEFAULT 0,
        encrypted_blob TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    // 2. banners
    batch.execute('''
      CREATE TABLE IF NOT EXISTS banners (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT,
        image_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT
      )
    ''');

    // 3. categories
    batch.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        parent_id TEXT,
        icon_key TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 4. shops
    batch.execute('''
      CREATE TABLE IF NOT EXISTS shops (
        id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        city TEXT,
        address TEXT,
        commercial_register TEXT,
        logo_path TEXT,
        cover_path TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        rejection_reason TEXT,
        decision_at TEXT,
        decision_visible_at TEXT,
        submitted_at TEXT,
        owner_json TEXT,
        products_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      )
    ''');

    // 5. shop_images
    batch.execute('''
      CREATE TABLE IF NOT EXISTS shop_images (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'gallery',
        created_at TEXT
      )
    ''');

    // 6. shop_documents
    batch.execute('''
      CREATE TABLE IF NOT EXISTS shop_documents (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        doc_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        created_at TEXT
      )
    ''');

    // 7. products
    batch.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        shop_name TEXT NOT NULL DEFAULT 'متجر',
        category_id TEXT,
        category_name TEXT,
        name TEXT NOT NULL,
        description TEXT,
        details_json TEXT,
        price REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'published',
        rating_avg REAL NOT NULL DEFAULT 5.0,
        rating_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_shop ON products(shop_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_status ON products(status)',
    );

    // 8. product_variants
    batch.execute('''
      CREATE TABLE IF NOT EXISTS product_variants (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_variants_product ON product_variants(product_id)',
    );

    // 9. product_images
    batch.execute('''
      CREATE TABLE IF NOT EXISTS product_images (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'gallery',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_images_product ON product_images(product_id)',
    );

    // 10. product_reviews
    batch.execute('''
      CREATE TABLE IF NOT EXISTS product_reviews (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        customer_name TEXT NOT NULL DEFAULT 'عميل',
        rating INTEGER NOT NULL DEFAULT 5,
        comment TEXT,
        created_at TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_reviews_product ON product_reviews(product_id)',
    );

    // 11. favorites
    batch.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        customer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        created_at TEXT,
        PRIMARY KEY (customer_id, product_id)
      )
    ''');

    // 12. cart_items (encrypted payload + relational keys)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS cart_items (
        customer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        variant_id TEXT,
        color TEXT NOT NULL,
        size TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        encrypted_blob TEXT NOT NULL,
        updated_at TEXT,
        PRIMARY KEY (customer_id, product_id, color, size)
      )
    ''');

    // 13. comparison_items
    batch.execute('''
      CREATE TABLE IF NOT EXISTS comparison_items (
        customer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        created_at TEXT,
        PRIMARY KEY (customer_id, product_id)
      )
    ''');

    // 14. orders (sensitive fields encrypted in encrypted_blob)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        customer_id TEXT NOT NULL,
        customer_email TEXT,
        customer_name TEXT,
        shop_id TEXT NOT NULL,
        shop_name TEXT NOT NULL DEFAULT 'متجر',
        status TEXT NOT NULL DEFAULT 'pending',
        total REAL NOT NULL DEFAULT 0,
        is_offline_pending INTEGER NOT NULL DEFAULT 0,
        encrypted_blob TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_shop ON orders(shop_id)',
    );

    // 15. order_items
    batch.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        variant_id TEXT,
        product_name TEXT NOT NULL,
        variant_info TEXT,
        unit_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 1,
        total_price REAL NOT NULL DEFAULT 0,
        image_path TEXT,
        encrypted_blob TEXT NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)',
    );

    // 16. notifications
    batch.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        audience TEXT NOT NULL DEFAULT 'all',
        shop_id TEXT,
        sender_role TEXT NOT NULL DEFAULT 'system',
        target_scope TEXT NOT NULL DEFAULT 'audience',
        target_user_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 17. platform_settings
    batch.execute('''
      CREATE TABLE IF NOT EXISTS platform_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        label TEXT NOT NULL
      )
    ''');

    // 18. sync_outbox (AES-256-GCM encrypted + HMAC-SHA256 signed queue)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        encrypted_payload TEXT NOT NULL,
        hmac_signature TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_status ON sync_outbox(status, created_at_ms)',
    );

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _onCreate(db, newVersion);
  }

  // ===========================================================================
  // 1. PROFILES & AUTH SESSION CACHING (ENCRYPTED)
  // ===========================================================================

  Future<void> saveUserProfile(
    AppUser user, {
    bool isCurrentSession = false,
  }) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final mapData = {
        'id': user.id,
        'email': user.email,
        'full_name': user.fullName,
        'phone': user.phone,
        'city': user.city,
        'address': user.address,
        'role': user.role.value,
        'is_active': user.isActive,
        'profile_completed': user.profileCompleted,
      };
      final encryptedBlob = OfflineSecurityService.instance.encryptMap(mapData);

      if (isCurrentSession) {
        await db.update(
          'profiles',
          {'is_current_session': 0},
          where: 'is_current_session = 1 AND id != ?',
          whereArgs: [user.id],
        );
      }

      await db.insert(
        'profiles',
        {
          'id': user.id,
          'email': user.email,
          'full_name': user.fullName,
          'phone': user.phone,
          'city': user.city,
          'address': user.address,
          'role': user.role.value,
          'is_active': user.isActive ? 1 : 0,
          'profile_completed': user.profileCompleted ? 1 : 0,
          'is_current_session': isCurrentSession ? 1 : 0,
          'encrypted_blob': encryptedBlob,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> saveUsersList(List<AppUser> users, {String? activeUserId}) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final user in users) {
        final mapData = {
          'id': user.id,
          'email': user.email,
          'full_name': user.fullName,
          'phone': user.phone,
          'city': user.city,
          'address': user.address,
          'role': user.role.value,
          'is_active': user.isActive,
          'profile_completed': user.profileCompleted,
        };
        final encryptedBlob = OfflineSecurityService.instance.encryptMap(
          mapData,
        );
        batch.insert(
          'profiles',
          {
            'id': user.id,
            'email': user.email,
            'full_name': user.fullName,
            'phone': user.phone,
            'city': user.city,
            'address': user.address,
            'role': user.role.value,
            'is_active': user.isActive ? 1 : 0,
            'profile_completed': user.profileCompleted ? 1 : 0,
            'is_current_session': (activeUserId != null && user.id == activeUserId)
                ? 1
                : 0,
            'encrypted_blob': encryptedBlob,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<AppUser?> getUserProfile(String userId) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeProfileRow(rows.first);
  }

  Future<AppUser?> getActiveSessionProfile() async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'profiles',
      where: 'is_current_session = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeProfileRow(rows.first);
  }

  Future<void> clearActiveSession() async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.update('profiles', {'is_current_session': 0});
    });
  }

  Future<List<AppUser>> getNonAdminUsers() async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'profiles',
      where: 'role != ?',
      whereArgs: ['admin'],
      orderBy: 'updated_at DESC',
    );
    final result = <AppUser>[];
    for (final row in rows) {
      final user = _decodeProfileRow(row);
      if (user != null) result.add(user);
    }
    return result;
  }

  AppUser? _decodeProfileRow(Map<String, Object?> row) {
    try {
      final blob = row['encrypted_blob'] as String?;
      if (blob != null && blob.isNotEmpty) {
        final decrypted = OfflineSecurityService.instance.decryptMap(blob);
        return AppUser.fromMap(decrypted);
      }
    } catch (_) {}
    return AppUser.fromMap({
      'id': row['id']?.toString() ?? '',
      'email': row['email']?.toString() ?? '',
      'full_name': row['full_name']?.toString(),
      'phone': row['phone']?.toString(),
      'city': row['city']?.toString(),
      'address': row['address']?.toString(),
      'role': row['role']?.toString() ?? 'customer',
      'is_active': (row['is_active'] as int? ?? 1) == 1,
      'profile_completed': (row['profile_completed'] as int? ?? 0) == 1,
    });
  }

  // ===========================================================================
  // 2. BANNERS
  // ===========================================================================

  Future<void> saveBanners(List<AdminBanner> banners) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final b in banners) {
        batch.insert(
          'banners',
          {
            'id': b.id,
            'title': b.title,
            'subtitle': b.subtitle,
            'image_path': b.imagePath,
            'is_active': b.isActive ? 1 : 0,
            'sort_order': b.sortOrder,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<AdminBanner>> getBanners({bool activeOnly = true}) async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'banners',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC',
    );
    return rows
        .map(
          (r) => AdminBanner(
            id: r['id']?.toString() ?? '',
            title: r['title']?.toString() ?? '',
            subtitle: r['subtitle']?.toString(),
            imagePath: r['image_path']?.toString(),
            isActive: (r['is_active'] as int? ?? 1) == 1,
            sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<void> deleteBanner(String bannerId) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.delete('banners', where: 'id = ?', whereArgs: [bannerId]);
    });
  }

  // ===========================================================================
  // 3. CATEGORIES
  // ===========================================================================

  Future<void> saveCategories(List<CatalogCategory> categories) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (var i = 0; i < categories.length; i++) {
        final c = categories[i];
        batch.insert(
          'categories',
          {
            'id': c.id,
            'name': c.name,
            'description': c.description,
            'is_active': c.isActive ? 1 : 0,
            'parent_id': c.parentId,
            'icon_key': c.iconKey,
            'sort_order': i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<CatalogCategory>> getCategories({bool activeOnly = true}) async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'categories',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows
        .map(
          (r) => CatalogCategory(
            id: r['id']?.toString() ?? '',
            name: r['name']?.toString() ?? '',
            description: r['description']?.toString(),
            isActive: (r['is_active'] as int? ?? 1) == 1,
            parentId: r['parent_id']?.toString(),
            iconKey: r['icon_key']?.toString(),
          ),
        )
        .toList();
  }

  // ===========================================================================
  // 4. SHOPS & SHOP MEDIA
  // ===========================================================================

  Future<void> saveCustomerShops(List<CustomerShop> shops) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final s in shops) {
        batch.insert(
          'shops',
          {
            'id': s.id,
            'owner_id': '',
            'name': s.name,
            'description': s.description,
            'city': s.city,
            'address': s.address,
            'logo_path': s.logoPath,
            'cover_path': s.coverPath,
            'status': 'approved',
            'products_count': s.productsCount,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveFullShop(Shop shop, {int? productsCount}) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final ownerJson = jsonEncode({
        'full_name': shop.ownerName,
        'email': shop.ownerEmail,
        'phone': shop.ownerPhone,
      });

      await db.insert(
        'shops',
        {
          'id': shop.id,
          'owner_id': shop.ownerId,
          'name': shop.name,
          'description': shop.description,
          'city': shop.city,
          'address': shop.address,
          'commercial_register': shop.commercialRegister,
          'logo_path': shop.logoPath,
          'cover_path': shop.coverPath,
          'status': shop.status.value,
          'rejection_reason': shop.rejectionReason,
          'decision_at': shop.decisionAt?.toIso8601String(),
          'decision_visible_at': shop.decisionVisibleAt?.toIso8601String(),
          'submitted_at': shop.submittedAt?.toIso8601String(),
          'owner_json': ownerJson,
          'products_count': productsCount ?? 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> saveFullShops(List<Shop> shops) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final shop in shops) {
        final ownerJson = jsonEncode({
          'full_name': shop.ownerName,
          'email': shop.ownerEmail,
          'phone': shop.ownerPhone,
        });
        batch.insert(
          'shops',
          {
            'id': shop.id,
            'owner_id': shop.ownerId,
            'name': shop.name,
            'description': shop.description,
            'city': shop.city,
            'address': shop.address,
            'commercial_register': shop.commercialRegister,
            'logo_path': shop.logoPath,
            'cover_path': shop.coverPath,
            'status': shop.status.value,
            'rejection_reason': shop.rejectionReason,
            'decision_at': shop.decisionAt?.toIso8601String(),
            'decision_visible_at': shop.decisionVisibleAt?.toIso8601String(),
            'submitted_at': shop.submittedAt?.toIso8601String(),
            'owner_json': ownerJson,
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<CustomerShop>> getCustomerShops() async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'shops',
      where: 'status = ?',
      whereArgs: ['approved'],
      orderBy: 'name ASC',
    );
    return rows.map(_mapRowToCustomerShop).toList();
  }

  Future<CustomerShop?> getCustomerShopById(String shopId) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'shops',
      where: 'id = ?',
      whereArgs: [shopId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowToCustomerShop(rows.first);
  }

  CustomerShop _mapRowToCustomerShop(Map<String, Object?> r) {
    return CustomerShop(
      id: r['id']?.toString() ?? '',
      name: r['name']?.toString() ?? 'متجر',
      description: r['description']?.toString(),
      city: r['city']?.toString(),
      address: r['address']?.toString(),
      logoPath: r['logo_path']?.toString(),
      coverPath: r['cover_path']?.toString(),
      productsCount: (r['products_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Shop?> getShopByOwnerId(String ownerId) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'shops',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowToShop(rows.first, forOwner: true);
  }

  Future<Shop?> getShopById(String shopId, {bool forOwner = false}) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'shops',
      where: 'id = ?',
      whereArgs: [shopId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapRowToShop(rows.first, forOwner: forOwner);
  }

  Future<List<Shop>> getAllNonDraftShops() async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'shops',
      where: 'status != ?',
      whereArgs: ['draft'],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => _mapRowToShop(r, forOwner: false)).toList();
  }

  Shop _mapRowToShop(Map<String, Object?> r, {required bool forOwner}) {
    Map<String, dynamic>? ownerMap;
    final ownerJson = r['owner_json'] as String?;
    if (ownerJson != null && ownerJson.isNotEmpty) {
      try {
        ownerMap = Map<String, dynamic>.from(jsonDecode(ownerJson) as Map);
      } catch (_) {}
    }

    return Shop.fromMap({
      'id': r['id']?.toString() ?? '',
      'owner_id': r['owner_id']?.toString() ?? '',
      'name': r['name']?.toString() ?? '',
      'description': r['description']?.toString(),
      'city': r['city']?.toString(),
      'address': r['address']?.toString(),
      'commercial_register': r['commercial_register']?.toString(),
      'logo_path': r['logo_path']?.toString(),
      'cover_path': r['cover_path']?.toString(),
      'status': r['status']?.toString() ?? 'draft',
      'rejection_reason': r['rejection_reason']?.toString(),
      'decision_at': r['decision_at']?.toString(),
      'decision_visible_at': r['decision_visible_at']?.toString(),
      'submitted_at': r['submitted_at']?.toString(),
      'owner': ownerMap,
    }, forOwner: forOwner);
  }

  Future<void> saveShopImages(String shopId, List<shop_models.ShopMediaItem> items) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final item in items) {
        batch.insert(
          'shop_images',
          {
            'id': item.id,
            'shop_id': shopId,
            'file_path': item.filePath,
            'kind': item.kind,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<shop_models.ShopMediaItem>> getShopImages(String shopId) async {
    final db = await database;
    if (db == null) return const [];
    final rows = await db.query(
      'shop_images',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => shop_models.ShopMediaItem(
            id: r['id']?.toString() ?? '',
            filePath: r['file_path']?.toString() ?? '',
            kind: r['kind']?.toString() ?? 'gallery',
          ),
        )
        .toList();
  }

  Future<void> saveShopDocuments(String shopId, List<shop_models.ShopMediaItem> docs) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final doc in docs) {
        batch.insert(
          'shop_documents',
          {
            'id': doc.id,
            'shop_id': shopId,
            'doc_type': doc.kind,
            'file_path': doc.filePath,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<shop_models.ShopMediaItem>> getShopDocuments(String shopId) async {
    final db = await database;
    if (db == null) return const [];
    final rows = await db.query(
      'shop_documents',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => shop_models.ShopMediaItem(
            id: r['id']?.toString() ?? '',
            filePath: r['file_path']?.toString() ?? '',
            kind: r['doc_type']?.toString() ?? 'document',
          ),
        )
        .toList();
  }

  // ===========================================================================
  // 5. PRODUCTS, VARIANTS, IMAGES & REVIEWS
  // ===========================================================================

  Future<void> saveCustomerProducts(
    List<customer_models.CustomerProduct> products,
  ) async {
    final db = await database;
    if (db == null || products.isEmpty) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      final nowIso = DateTime.now().toIso8601String();

      for (final pItem in products) {
        batch.insert(
          'products',
          {
            'id': pItem.id,
            'shop_id': pItem.shopId,
            'shop_name': pItem.shopName,
            'category_id': pItem.categoryId,
            'category_name': pItem.categoryName,
            'name': pItem.name,
            'description': pItem.description,
            'details_json': jsonEncode(pItem.details),
            'price': pItem.price,
            'status': pItem.status,
            'rating_avg': pItem.ratingAvg,
            'rating_count': pItem.ratingCount,
            'created_at': nowIso,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        batch.delete(
          'product_variants',
          where: 'product_id = ?',
          whereArgs: [pItem.id],
        );
        for (final v in pItem.variants) {
          batch.insert(
            'product_variants',
            {
              'id': v.id.isNotEmpty
                  ? v.id
                  : '${pItem.id}_${v.color}_${v.size}',
              'product_id': pItem.id,
              'color': v.color,
              'size': v.size,
              'stock': v.stock,
              'is_active': v.isActive ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        batch.delete(
          'product_images',
          where: 'product_id = ?',
          whereArgs: [pItem.id],
        );
        for (var i = 0; i < pItem.images.length; i++) {
          final img = pItem.images[i];
          batch.insert(
            'product_images',
            {
              'id': img.id.isNotEmpty ? img.id : '${pItem.id}_img_$i',
              'product_id': pItem.id,
              'file_path': img.filePath,
              'kind': img.kind,
              'sort_order': img.sortOrder,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> saveShopProducts(List<shop_models.ShopProduct> products) async {
    final db = await database;
    if (db == null || products.isEmpty) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      final nowIso = DateTime.now().toIso8601String();

      for (final pItem in products) {
        batch.insert(
          'products',
          {
            'id': pItem.id,
            'shop_id': pItem.shopId,
            'shop_name': 'متجر',
            'category_id': pItem.categoryId,
            'category_name': pItem.categoryName,
            'name': pItem.name,
            'description': pItem.description,
            'details_json': jsonEncode(pItem.details),
            'price': pItem.price,
            'status': pItem.status,
            'created_at': nowIso,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        batch.delete(
          'product_variants',
          where: 'product_id = ?',
          whereArgs: [pItem.id],
        );
        for (final v in pItem.variants) {
          batch.insert(
            'product_variants',
            {
              'id': v.id.isNotEmpty
                  ? v.id
                  : '${pItem.id}_${v.color}_${v.size}',
              'product_id': pItem.id,
              'color': v.color,
              'size': v.size,
              'stock': v.stock,
              'is_active': v.isActive ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        batch.delete(
          'product_images',
          where: 'product_id = ?',
          whereArgs: [pItem.id],
        );
        for (var i = 0; i < pItem.images.length; i++) {
          final img = pItem.images[i];
          batch.insert(
            'product_images',
            {
              'id': img.id.isNotEmpty ? img.id : '${pItem.id}_img_$i',
              'product_id': pItem.id,
              'file_path': img.filePath,
              'kind': img.kind,
              'sort_order': i,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await batch.commit(noResult: true);
    });
  }

  Future<PaginatedPage<customer_models.CustomerProduct>> getCustomerProductsPage({
    String? customerId,
    String? categoryId,
    String? shopId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? color,
    String? size,
    bool inStockOnly = false,
    double? minRating,
    ProductSortOption sort = ProductSortOption.newest,
    int limit = kProductPageSize,
    int offset = 0,
    String? excludeProductId,
  }) async {
    final db = await database;
    if (db == null) {
      return const PaginatedPage<customer_models.CustomerProduct>(
        items: [],
        rawCount: 0,
      );
    }

    final whereClauses = <String>["status = 'published'"];
    final whereArgs = <Object?>[];

    if (excludeProductId != null && excludeProductId.isNotEmpty) {
      whereClauses.add('id != ?');
      whereArgs.add(excludeProductId);
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      final allCategories = await getCategories(activeOnly: true);
      final branchIds = categoryBranchIds(allCategories, categoryId).toList();
      if (branchIds.isNotEmpty) {
        final placeholders = List.filled(branchIds.length, '?').join(',');
        whereClauses.add('category_id IN ($placeholders)');
        whereArgs.addAll(branchIds);
      }
    }

    if (shopId != null && shopId.isNotEmpty) {
      whereClauses.add('shop_id = ?');
      whereArgs.add(shopId);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('LOWER(name) LIKE ?');
      whereArgs.add('%${search.trim().toLowerCase()}%');
    }

    if (minPrice != null) {
      whereClauses.add('price >= ?');
      whereArgs.add(minPrice);
    }

    if (maxPrice != null) {
      whereClauses.add('price <= ?');
      whereArgs.add(maxPrice);
    }

    final orderBy = switch (sort) {
      ProductSortOption.priceAsc => 'price ASC, created_at DESC',
      ProductSortOption.priceDesc => 'price DESC, created_at DESC',
      ProductSortOption.nameAsc => 'name ASC, created_at DESC',
      _ => 'created_at DESC',
    };

    final rawRows = await db.query(
      'products',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset < 0 ? 0 : offset,
    );

    final favoriteIds = customerId != null
        ? await getFavoriteProductIds(customerId)
        : const <String>{};

    final mapped = await _hydrateCustomerProducts(rawRows, favoriteIds);
    final refined = applyCustomerProductFilter(
      mapped,
      ProductFilter(
        shopId: shopId,
        minPrice: minPrice,
        maxPrice: maxPrice,
        color: color,
        size: size,
        inStockOnly: inStockOnly,
        minRating: minRating,
        sort: sort,
      ),
    );

    return PaginatedPage<customer_models.CustomerProduct>(
      items: refined,
      rawCount: rawRows.length,
    );
  }

  Future<customer_models.CustomerProduct?> getCustomerProductById(
    String productId, {
    String? customerId,
  }) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final favoriteIds = customerId != null
        ? await getFavoriteProductIds(customerId)
        : const <String>{};
    final list = await _hydrateCustomerProducts(rows, favoriteIds);
    if (list.isEmpty) return null;

    final reviews = await getProductReviews(productId);
    if (reviews.isNotEmpty) {
      final sum = reviews.fold<int>(0, (s, r) => s + r.rating);
      return list.first.copyWith(
        ratingAvg: sum / reviews.length,
        ratingCount: reviews.length,
      );
    }
    return list.first;
  }

  Future<List<customer_models.CustomerProduct>> _hydrateCustomerProducts(
    List<Map<String, Object?>> productRows,
    Set<String> favoriteIds,
  ) async {
    final db = await database;
    if (db == null || productRows.isEmpty) return const [];

    final productIds = productRows
        .map((r) => r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (productIds.isEmpty) return const [];

    final placeholders = List.filled(productIds.length, '?').join(',');

    final variantRows = await db.query(
      'product_variants',
      where: 'product_id IN ($placeholders)',
      whereArgs: productIds,
    );
    final imageRows = await db.query(
      'product_images',
      where: 'product_id IN ($placeholders)',
      whereArgs: productIds,
      orderBy: 'sort_order ASC',
    );

    final variantsByProduct = <String, List<customer_models.ProductVariant>>{};
    for (final v in variantRows) {
      final pid = v['product_id']?.toString() ?? '';
      (variantsByProduct[pid] ??= []).add(
        customer_models.ProductVariant(
          id: v['id']?.toString() ?? '',
          productId: pid,
          color: v['color']?.toString() ?? '',
          size: v['size']?.toString() ?? '',
          stock: (v['stock'] as num?)?.toInt() ?? 0,
          isActive: (v['is_active'] as int? ?? 1) == 1,
        ),
      );
    }

    final imagesByProduct = <String, List<customer_models.ProductImage>>{};
    for (final img in imageRows) {
      final pid = img['product_id']?.toString() ?? '';
      (imagesByProduct[pid] ??= []).add(
        customer_models.ProductImage(
          id: img['id']?.toString() ?? '',
          productId: pid,
          filePath: img['file_path']?.toString() ?? '',
          kind: img['kind']?.toString() ?? 'gallery',
          sortOrder: (img['sort_order'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    final results = <customer_models.CustomerProduct>[];
    for (final row in productRows) {
      final pid = row['id']?.toString() ?? '';
      Map<String, dynamic> details = const {};
      final detailsJson = row['details_json'] as String?;
      if (detailsJson != null && detailsJson.isNotEmpty) {
        try {
          details = Map<String, dynamic>.from(jsonDecode(detailsJson) as Map);
        } catch (_) {}
      }

      results.add(
        customer_models.CustomerProduct(
          id: pid,
          shopId: row['shop_id']?.toString() ?? '',
          shopName: row['shop_name']?.toString() ?? 'متجر',
          categoryId: row['category_id']?.toString(),
          categoryName: row['category_name']?.toString(),
          name: row['name']?.toString() ?? '',
          description: row['description']?.toString(),
          details: details,
          price: (row['price'] as num?)?.toDouble() ?? 0.0,
          status: row['status']?.toString() ?? 'published',
          variants: (variantsByProduct[pid] ?? const [])
              .where((v) => v.isActive)
              .toList(),
          images: imagesByProduct[pid] ?? const [],
          ratingAvg: (row['rating_avg'] as num?)?.toDouble() ?? 5.0,
          ratingCount: (row['rating_count'] as num?)?.toInt() ?? 0,
          isFavorite: favoriteIds.contains(pid),
        ),
      );
    }

    return results;
  }

  Future<PaginatedPage<shop_models.ShopProduct>> getShopProductsPage({
    required String shopId,
    int limit = kProductPageSize,
    int offset = 0,
    String? status,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    String? search,
    ProductSortOption sort = ProductSortOption.newest,
  }) async {
    final db = await database;
    if (db == null) {
      return const PaginatedPage<shop_models.ShopProduct>(
        items: [],
        rawCount: 0,
      );
    }

    final whereClauses = <String>['shop_id = ?', "status != 'deleted'"];
    final whereArgs = <Object?>[shopId];

    if (status != null && status.isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      whereClauses.add('category_id = ?');
      whereArgs.add(categoryId);
    }
    if (minPrice != null) {
      whereClauses.add('price >= ?');
      whereArgs.add(minPrice);
    }
    if (maxPrice != null) {
      whereClauses.add('price <= ?');
      whereArgs.add(maxPrice);
    }
    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('LOWER(name) LIKE ?');
      whereArgs.add('%${search.trim().toLowerCase()}%');
    }

    final orderBy = switch (sort) {
      ProductSortOption.priceAsc => 'price ASC, updated_at DESC',
      ProductSortOption.priceDesc => 'price DESC, updated_at DESC',
      ProductSortOption.nameAsc => 'name ASC, updated_at DESC',
      _ => 'updated_at DESC',
    };

    final rawRows = await db.query(
      'products',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset < 0 ? 0 : offset,
    );

    final items = await _hydrateShopProducts(rawRows);
    return PaginatedPage<shop_models.ShopProduct>(
      items: items,
      rawCount: rawRows.length,
    );
  }

  Future<shop_models.ShopProduct?> getShopProductById(String productId) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final list = await _hydrateShopProducts(rows);
    return list.isEmpty ? null : list.first;
  }

  Future<List<shop_models.ShopProduct>> _hydrateShopProducts(
    List<Map<String, Object?>> productRows,
  ) async {
    final db = await database;
    if (db == null || productRows.isEmpty) return const [];

    final productIds = productRows
        .map((r) => r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (productIds.isEmpty) return const [];

    final placeholders = List.filled(productIds.length, '?').join(',');
    final variantRows = await db.query(
      'product_variants',
      where: 'product_id IN ($placeholders)',
      whereArgs: productIds,
    );
    final imageRows = await db.query(
      'product_images',
      where: 'product_id IN ($placeholders)',
      whereArgs: productIds,
      orderBy: 'sort_order ASC',
    );

    final variantsByProduct = <String, List<shop_models.ProductVariant>>{};
    for (final v in variantRows) {
      final pid = v['product_id']?.toString() ?? '';
      (variantsByProduct[pid] ??= []).add(
        shop_models.ProductVariant(
          id: v['id']?.toString() ?? '',
          productId: pid,
          color: v['color']?.toString() ?? '',
          size: v['size']?.toString() ?? '',
          stock: (v['stock'] as num?)?.toInt() ?? 0,
          isActive: (v['is_active'] as int? ?? 1) == 1,
        ),
      );
    }

    final imagesByProduct = <String, List<shop_models.ProductImage>>{};
    for (final img in imageRows) {
      final pid = img['product_id']?.toString() ?? '';
      (imagesByProduct[pid] ??= []).add(
        shop_models.ProductImage(
          id: img['id']?.toString() ?? '',
          productId: pid,
          filePath: img['file_path']?.toString() ?? '',
          kind: img['kind']?.toString() ?? 'gallery',
        ),
      );
    }

    return productRows.map((row) {
      final pid = row['id']?.toString() ?? '';
      Map<String, dynamic> details = const {};
      final detailsJson = row['details_json'] as String?;
      if (detailsJson != null && detailsJson.isNotEmpty) {
        try {
          details = Map<String, dynamic>.from(jsonDecode(detailsJson) as Map);
        } catch (_) {}
      }

      return shop_models.ShopProduct(
        id: pid,
        shopId: row['shop_id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        description: row['description']?.toString(),
        price: (row['price'] as num?)?.toDouble() ?? 0.0,
        status: row['status']?.toString() ?? 'draft',
        categoryId: row['category_id']?.toString(),
        categoryName: row['category_name']?.toString(),
        variants: variantsByProduct[pid] ?? const [],
        images: imagesByProduct[pid] ?? const [],
        details: details,
      );
    }).toList();
  }

  Future<PaginatedPage<AdminProduct>> getAdminProductsPage({
    int limit = kProductPageSize,
    int offset = 0,
    String? status,
    double? minPrice,
    double? maxPrice,
    String? search,
    ProductSortOption sort = ProductSortOption.newest,
  }) async {
    final db = await database;
    if (db == null) {
      return const PaginatedPage<AdminProduct>(items: [], rawCount: 0);
    }

    final whereClauses = <String>["status != 'deleted'"];
    final whereArgs = <Object?>[];

    if (status != null && status.isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    if (minPrice != null) {
      whereClauses.add('price >= ?');
      whereArgs.add(minPrice);
    }
    if (maxPrice != null) {
      whereClauses.add('price <= ?');
      whereArgs.add(maxPrice);
    }
    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('LOWER(name) LIKE ?');
      whereArgs.add('%${search.trim().toLowerCase()}%');
    }

    final orderBy = switch (sort) {
      ProductSortOption.priceAsc => 'price ASC, updated_at DESC',
      ProductSortOption.priceDesc => 'price DESC, updated_at DESC',
      ProductSortOption.nameAsc => 'name ASC, updated_at DESC',
      _ => 'updated_at DESC',
    };

    final rawRows = await db.query(
      'products',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset < 0 ? 0 : offset,
    );

    final items = rawRows
        .map(
          (r) => AdminProduct(
            id: r['id']?.toString() ?? '',
            name: r['name']?.toString() ?? '',
            description: r['description']?.toString(),
            price: (r['price'] as num?)?.toDouble() ?? 0.0,
            status: r['status']?.toString() ?? 'draft',
            shopName: r['shop_name']?.toString(),
            categoryName: r['category_name']?.toString(),
          ),
        )
        .toList();

    return PaginatedPage<AdminProduct>(items: items, rawCount: rawRows.length);
  }

  Future<void> updateProductStatusLocal(String productId, String status) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.update(
        'products',
        {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [productId],
      );
    });
  }

  Future<void> saveProductReviews(
    String productId,
    List<customer_models.ProductReview> reviews,
  ) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final r in reviews) {
        batch.insert(
          'product_reviews',
          {
            'id': r.id.isNotEmpty
                ? r.id
                : '${r.productId}_${r.customerId}',
            'product_id': productId,
            'customer_id': r.customerId,
            'customer_name': r.customerName,
            'rating': r.rating,
            'comment': r.comment,
            'created_at': r.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<customer_models.ProductReview>> getProductReviews(
    String productId,
  ) async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'product_reviews',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => customer_models.ProductReview(
            id: r['id']?.toString() ?? '',
            productId: r['product_id']?.toString() ?? '',
            customerId: r['customer_id']?.toString() ?? '',
            customerName: r['customer_name']?.toString() ?? 'عميل',
            rating: (r['rating'] as num?)?.toInt() ?? 5,
            comment: r['comment']?.toString(),
            createdAt:
                DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> upsertProductReviewLocal({
    required String productId,
    required String customerId,
    required String customerName,
    required int rating,
    String? comment,
  }) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      await db.insert(
        'product_reviews',
        {
          'id': '${productId}_$customerId',
          'product_id': productId,
          'customer_id': customerId,
          'customer_name': customerName,
          'rating': rating,
          'comment': comment,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ===========================================================================
  // 6. FAVORITES
  // ===========================================================================

  Future<void> saveFavoriteIds(String customerId, Set<String> productIds) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      batch.delete(
        'favorites',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      final nowIso = DateTime.now().toIso8601String();
      for (final pid in productIds) {
        batch.insert(
          'favorites',
          {
            'customer_id': customerId,
            'product_id': pid,
            'created_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Set<String>> getFavoriteProductIds(String customerId) async {
    final db = await database;
    if (db == null) return const {};

    final rows = await db.query(
      'favorites',
      columns: ['product_id'],
      where: 'customer_id = ?',
      whereArgs: [customerId],
    );
    return rows.map((r) => r['product_id']?.toString() ?? '').toSet();
  }

  Future<bool> toggleFavoriteLocal({
    required String customerId,
    required String productId,
  }) async {
    final db = await database;
    if (db == null) return false;

    return _writeLock.synchronized(() async {
      final existing = await db.query(
        'favorites',
        where: 'customer_id = ? AND product_id = ?',
        whereArgs: [customerId, productId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await db.delete(
          'favorites',
          where: 'customer_id = ? AND product_id = ?',
          whereArgs: [customerId, productId],
        );
        return false;
      } else {
        await db.insert(
          'favorites',
          {
            'customer_id': customerId,
            'product_id': productId,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }
    });
  }

  Future<PaginatedPage<customer_models.CustomerProduct>> getFavoritesPage({
    required String customerId,
    int limit = kProductPageSize,
    int offset = 0,
  }) async {
    final db = await database;
    if (db == null) {
      return const PaginatedPage<customer_models.CustomerProduct>(
        items: [],
        rawCount: 0,
      );
    }

    final favRows = await db.query(
      'favorites',
      columns: ['product_id'],
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset < 0 ? 0 : offset,
    );

    if (favRows.isEmpty) {
      return const PaginatedPage<customer_models.CustomerProduct>(
        items: [],
        rawCount: 0,
      );
    }

    final ids = favRows
        .map((r) => r['product_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final productRows = await db.query(
      'products',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );

    final hydrated = await _hydrateCustomerProducts(productRows, ids.toSet());
    final byId = {for (final p in hydrated) p.id: p};
    final ordered = ids
        .map((id) => byId[id])
        .whereType<customer_models.CustomerProduct>()
        .toList();

    return PaginatedPage<customer_models.CustomerProduct>(
      items: ordered,
      rawCount: favRows.length,
    );
  }

  // ===========================================================================
  // 7. CART ITEMS (ENCRYPTED)
  // ===========================================================================

  Future<void> saveCartItems(String customerId, List<CartItem> items) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      batch.delete(
        'cart_items',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      final nowIso = DateTime.now().toIso8601String();
      for (final item in items) {
        final encrypted = OfflineSecurityService.instance.encryptMap({
          'id': item.id,
          'product_id': item.productId,
          'product_name': item.productName,
          'shop_id': item.shopId,
          'shop_name': item.shopName,
          'variant_id': item.variantId,
          'color': item.color,
          'size': item.size,
          'unit_price': item.unitPrice,
          'quantity': item.quantity,
          'image_path': item.imagePath,
          'max_stock': item.maxStock,
        });
        batch.insert(
          'cart_items',
          {
            'customer_id': customerId,
            'product_id': item.productId,
            'variant_id': item.variantId,
            'color': item.color,
            'size': item.size,
            'quantity': item.quantity,
            'encrypted_blob': encrypted,
            'updated_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertCartItemLocal({
    required String customerId,
    required String productId,
    String? variantId,
    required String color,
    required String size,
    required int quantity,
  }) async {
    final db = await database;
    if (db == null) return;

    final product = await getCustomerProductById(
      productId,
      customerId: customerId,
    );

    await _writeLock.synchronized(() async {
      int maxStock = 999;
      if (product != null) {
        for (final v in product.variants) {
          if ((variantId != null && v.id == variantId) ||
              (v.color == color && v.size == size)) {
            maxStock = v.stock > 0 ? v.stock : 1;
            break;
          }
        }
      }

      final encrypted = OfflineSecurityService.instance.encryptMap({
        'id': '${productId}_${color}_$size',
        'product_id': productId,
        'product_name': product?.name ?? 'منتج',
        'shop_id': product?.shopId ?? '',
        'shop_name': product?.shopName ?? 'متجر',
        'variant_id': variantId,
        'color': color,
        'size': size,
        'unit_price': product?.price ?? 0.0,
        'quantity': quantity,
        'image_path': product?.coverImage,
        'max_stock': maxStock,
      });

      await db.insert(
        'cart_items',
        {
          'customer_id': customerId,
          'product_id': productId,
          'variant_id': variantId,
          'color': color,
          'size': size,
          'quantity': quantity,
          'encrypted_blob': encrypted,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> removeCartItemLocal({
    required String customerId,
    required String productId,
    required String color,
    required String size,
  }) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      await db.delete(
        'cart_items',
        where: 'customer_id = ? AND product_id = ? AND color = ? AND size = ?',
        whereArgs: [customerId, productId, color, size],
      );
    });
  }

  Future<void> clearCartItemsLocal(String customerId) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      await db.delete(
        'cart_items',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
    });
  }

  Future<List<CartItem>> getCartItems(String customerId) async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'cart_items',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'updated_at ASC',
    );

    final items = <CartItem>[];
    for (final r in rows) {
      try {
        final blob = r['encrypted_blob'] as String?;
        if (blob != null && blob.isNotEmpty) {
          final m = OfflineSecurityService.instance.decryptMap(blob);
          items.add(
            CartItem(
              id: m['id']?.toString() ??
                  '${r['product_id']}_${r['color']}_${r['size']}',
              productId: m['product_id']?.toString() ?? '',
              productName: m['product_name']?.toString() ?? 'منتج',
              shopId: m['shop_id']?.toString() ?? '',
              shopName: m['shop_name']?.toString() ?? 'متجر',
              variantId: m['variant_id']?.toString(),
              color: m['color']?.toString() ?? '',
              size: m['size']?.toString() ?? '',
              unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
              quantity: (m['quantity'] as num?)?.toInt() ?? 1,
              imagePath: m['image_path']?.toString(),
              maxStock: (m['max_stock'] as num?)?.toInt() ?? 999,
            ),
          );
          continue;
        }
      } catch (_) {}
    }
    return items;
  }

  // ===========================================================================
  // 8. COMPARISON ITEMS
  // ===========================================================================

  Future<void> saveComparisonProducts(
    String customerId,
    List<customer_models.CustomerProduct> products,
  ) async {
    final db = await database;
    if (db == null) return;

    await saveCustomerProducts(products);

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      batch.delete(
        'comparison_items',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      final nowIso = DateTime.now().toIso8601String();
      for (final pItem in products) {
        batch.insert(
          'comparison_items',
          {
            'customer_id': customerId,
            'product_id': pItem.id,
            'created_at': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<customer_models.CustomerProduct>> getComparisonProducts(
    String customerId,
  ) async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'comparison_items',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at ASC',
    );
    if (rows.isEmpty) return const [];

    final ids = rows
        .map((r) => r['product_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final productRows = await db.query(
      'products',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    final favIds = await getFavoriteProductIds(customerId);
    return _hydrateCustomerProducts(productRows, favIds);
  }

  Future<void> addComparisonProductLocal(
    String customerId,
    String productId,
  ) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.insert(
        'comparison_items',
        {
          'customer_id': customerId,
          'product_id': productId,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> removeComparisonProductLocal(
    String customerId,
    String productId,
  ) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.delete(
        'comparison_items',
        where: 'customer_id = ? AND product_id = ?',
        whereArgs: [customerId, productId],
      );
    });
  }

  Future<void> clearComparisonProductsLocal(String customerId) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.delete(
        'comparison_items',
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
    });
  }

  // ===========================================================================
  // 9. ORDERS & ORDER ITEMS (ENCRYPTED)
  // ===========================================================================

  Future<void> saveCustomerOrders(
    List<CustomerOrder> orders, {
    bool isOfflinePending = false,
  }) async {
    final db = await database;
    if (db == null || orders.isEmpty) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();

      for (final order in orders) {
        final encryptedOrder = OfflineSecurityService.instance.encryptMap({
          'id': order.id,
          'customer_id': order.customerId,
          'shop_id': order.shopId,
          'shop_name': order.shopName,
          'status': order.status,
          'total': order.total,
          'delivery_address': order.deliveryAddress,
          'phone': order.phone,
          'notes': order.notes,
          'created_at': order.createdAt.toIso8601String(),
        });

        batch.insert(
          'orders',
          {
            'id': order.id,
            'customer_id': order.customerId,
            'shop_id': order.shopId,
            'shop_name': order.shopName,
            'status': order.status,
            'total': order.total,
            'is_offline_pending': isOfflinePending ? 1 : 0,
            'encrypted_blob': encryptedOrder,
            'created_at': order.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        batch.delete(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [order.id],
        );

        for (final item in order.items) {
          final encryptedItem = OfflineSecurityService.instance.encryptMap({
            'id': item.id,
            'order_id': order.id,
            'product_id': item.productId,
            'variant_id': item.variantId,
            'product_name': item.productName,
            'variant_info': item.variantInfo,
            'unit_price': item.unitPrice,
            'quantity': item.quantity,
            'total_price': item.totalPrice,
            'image_path': item.imagePath,
          });

          batch.insert(
            'order_items',
            {
              'id': item.id.isNotEmpty
                  ? item.id
                  : '${order.id}_${item.productId}_${item.variantId ?? ''}',
              'order_id': order.id,
              'product_id': item.productId,
              'variant_id': item.variantId,
              'product_name': item.productName,
              'variant_info': item.variantInfo,
              'unit_price': item.unitPrice,
              'quantity': item.quantity,
              'total_price': item.totalPrice,
              'image_path': item.imagePath,
              'encrypted_blob': encryptedItem,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> saveShopOrders(
    String shopId,
    List<shop_models.ShopOrder> orders,
  ) async {
    final db = await database;
    if (db == null || orders.isEmpty) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final o in orders) {
        final encryptedOrder = OfflineSecurityService.instance.encryptMap({
          'id': o.id,
          'customer_id': o.customerId ?? '',
          'customer_email': o.customerEmail,
          'customer_name': o.customerName,
          'shop_id': shopId,
          'status': o.status,
          'total': o.total,
          'created_at': o.createdAt.toIso8601String(),
        });

        batch.insert(
          'orders',
          {
            'id': o.id,
            'customer_id': o.customerId ?? '',
            'customer_email': o.customerEmail,
            'customer_name': o.customerName,
            'shop_id': shopId,
            'shop_name': 'متجر',
            'status': o.status,
            'total': o.total,
            'is_offline_pending': 0,
            'encrypted_blob': encryptedOrder,
            'created_at': o.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> replaceTemporaryOrder(
    String tempOrderId,
    CustomerOrder officialOrder,
  ) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      await db.delete('orders', where: 'id = ?', whereArgs: [tempOrderId]);
      await db.delete(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [tempOrderId],
      );
    });
    await saveCustomerOrders([officialOrder], isOfflinePending: false);
  }

  Future<List<CustomerOrder>> getCustomerOrders(String customerId) async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'orders',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    if (rows.isEmpty) return const [];

    final result = <CustomerOrder>[];
    for (final r in rows) {
      final order = await _decodeCustomerOrderRow(r);
      if (order != null) result.add(order);
    }
    return result;
  }

  Future<CustomerOrder?> getCustomerOrderById(String orderId) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeCustomerOrderRow(rows.first);
  }

  Future<CustomerOrder?> _decodeCustomerOrderRow(
    Map<String, Object?> r,
  ) async {
    final db = await database;
    if (db == null) return null;

    final orderId = r['id']?.toString() ?? '';
    Map<String, dynamic> orderMap;
    try {
      final blob = r['encrypted_blob'] as String?;
      if (blob != null && blob.isNotEmpty) {
        orderMap = OfflineSecurityService.instance.decryptMap(blob);
      } else {
        orderMap = Map<String, dynamic>.from(r);
      }
    } catch (_) {
      orderMap = Map<String, dynamic>.from(r);
    }

    final itemRows = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    final items = <CustomerOrderItem>[];
    for (final ir in itemRows) {
      try {
        final iblob = ir['encrypted_blob'] as String?;
        if (iblob != null && iblob.isNotEmpty) {
          final im = OfflineSecurityService.instance.decryptMap(iblob);
          items.add(CustomerOrderItem.fromMap(im));
          continue;
        }
      } catch (_) {}
      items.add(CustomerOrderItem.fromMap(Map<String, dynamic>.from(ir)));
    }

    return CustomerOrder.fromMap(orderMap, items: items);
  }

  Future<List<shop_models.ShopOrder>> getShopOrders(String shopId) async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query(
      'orders',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'created_at DESC',
    );

    return rows.map((r) {
      return shop_models.ShopOrder(
        id: r['id']?.toString() ?? '',
        status: r['status']?.toString() ?? 'pending',
        total: (r['total'] as num?)?.toDouble() ?? 0.0,
        createdAt:
            DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
        customerId: r['customer_id']?.toString(),
        customerEmail: r['customer_email']?.toString(),
        customerName: r['customer_name']?.toString(),
      );
    }).toList();
  }

  Future<List<AdminOrder>> getAdminOrders() async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query('orders', orderBy: 'created_at DESC');
    return rows.map((r) {
      return AdminOrder(
        id: r['id']?.toString() ?? '',
        status: r['status']?.toString() ?? 'pending',
        total: (r['total'] as num?)?.toDouble() ?? 0.0,
        createdAt:
            DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
        shopName: r['shop_name']?.toString(),
        customerEmail: r['customer_email']?.toString(),
      );
    }).toList();
  }

  Future<void> updateOrderStatusLocal(String orderId, String status) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final rows = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      Map<String, dynamic> mapData = {};
      try {
        final blob = row['encrypted_blob'] as String?;
        if (blob != null && blob.isNotEmpty) {
          mapData = OfflineSecurityService.instance.decryptMap(blob);
        }
      } catch (_) {}
      mapData['status'] = status;
      final reEncrypted = OfflineSecurityService.instance.encryptMap(mapData);

      await db.update(
        'orders',
        {
          'status': status,
          'encrypted_blob': reEncrypted,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  // ===========================================================================
  // 10. NOTIFICATIONS & PLATFORM SETTINGS
  // ===========================================================================

  Future<void> saveNotifications(List<AdminNotification> notifications) async {
    final db = await database;
    if (db == null || notifications.isEmpty) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final n in notifications) {
        batch.insert(
          'notifications',
          {
            'id': n.id,
            'title': n.title,
            'body': n.body,
            'audience': n.audience,
            'shop_id': n.shopId,
            'sender_role': n.senderRole,
            'target_scope': n.targetScope,
            'created_at': n.createdAt.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<AdminNotification>> getNotifications({
    List<String>? audiences,
  }) async {
    final db = await database;
    if (db == null) return const [];

    String? where;
    List<Object?>? whereArgs;
    if (audiences != null && audiences.isNotEmpty) {
      final placeholders = List.filled(audiences.length, '?').join(',');
      where = 'audience IN ($placeholders)';
      whereArgs = audiences;
    }

    final rows = await db.query(
      'notifications',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => AdminNotification(
            id: r['id']?.toString() ?? '',
            title: r['title']?.toString() ?? '',
            body: r['body']?.toString() ?? '',
            audience: r['audience']?.toString() ?? 'all',
            createdAt:
                DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                DateTime.now(),
            shopId: r['shop_id']?.toString(),
            senderRole: r['sender_role']?.toString() ?? 'system',
            targetScope: r['target_scope']?.toString() ?? 'audience',
          ),
        )
        .toList();
  }

  Future<void> savePlatformSettings(List<PlatformSetting> settings) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final batch = db.batch();
      for (final s in settings) {
        batch.insert(
          'platform_settings',
          {
            'key': s.key,
            'value': s.value,
            'label': s.label,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<PlatformSetting>> getPlatformSettings() async {
    final db = await database;
    if (db == null) return const [];

    final rows = await db.query('platform_settings', orderBy: 'key ASC');
    return rows
        .map(
          (r) => PlatformSetting(
            key: r['key']?.toString() ?? '',
            value: r['value']?.toString() ?? '',
            label: r['label']?.toString() ?? '',
          ),
        )
        .toList();
  }

  // ===========================================================================
  // 11. COMPUTED STATS FOR SHOP & ADMIN OFFLINE DASHBOARDS
  // ===========================================================================

  Future<shop_models.ShopStats> computeShopStats(String shopId) async {
    final db = await database;
    if (db == null) {
      return const shop_models.ShopStats(
        products: 0,
        publishedProducts: 0,
        orders: 0,
        pendingOrders: 0,
        salesTotal: 0,
        stockUnits: 0,
      );
    }

    final productsRows = await db.query(
      'products',
      where: "shop_id = ? AND status != 'deleted'",
      whereArgs: [shopId],
    );
    final publishedCount = productsRows
        .where((r) => r['status'] == 'published')
        .length;

    final ordersRows = await db.query(
      'orders',
      where: 'shop_id = ?',
      whereArgs: [shopId],
    );
    final pendingOrdersCount = ordersRows
        .where((r) => r['status'] == 'pending')
        .length;
    final salesTotal = ordersRows
        .where((r) => r['status'] != 'cancelled')
        .fold<double>(
          0.0,
          (sum, r) => sum + ((r['total'] as num?)?.toDouble() ?? 0.0),
        );

    int stockUnits = 0;
    if (productsRows.isNotEmpty) {
      final pids = productsRows.map((r) => r['id']?.toString() ?? '').toList();
      final placeholders = List.filled(pids.length, '?').join(',');
      final vRows = await db.query(
        'product_variants',
        where: 'product_id IN ($placeholders)',
        whereArgs: pids,
      );
      stockUnits = vRows.fold<int>(
        0,
        (sum, r) => sum + ((r['stock'] as num?)?.toInt() ?? 0),
      );
    }

    return shop_models.ShopStats(
      products: productsRows.length,
      publishedProducts: publishedCount,
      orders: ordersRows.length,
      pendingOrders: pendingOrdersCount,
      salesTotal: salesTotal,
      stockUnits: stockUnits,
    );
  }

  Future<AdminStats> computeAdminStats() async {
    final db = await database;
    if (db == null) {
      return const AdminStats(
        customers: 0,
        shops: 0,
        pendingShops: 0,
        approvedShops: 0,
        suspendedShops: 0,
        products: 0,
        hiddenProducts: 0,
        orders: 0,
        categories: 0,
        banners: 0,
        notifications: 0,
      );
    }

    final customers = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM profiles WHERE role = 'customer'",
          ),
        ) ??
        0;
    final shops = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM shops WHERE status != 'draft'",
          ),
        ) ??
        0;
    final pendingShops = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM shops WHERE status = 'pending'",
          ),
        ) ??
        0;
    final approvedShops = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM shops WHERE status = 'approved'",
          ),
        ) ??
        0;
    final suspendedShops = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM shops WHERE status = 'suspended'",
          ),
        ) ??
        0;
    final products = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM products WHERE status != 'deleted'",
          ),
        ) ??
        0;
    final hiddenProducts = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM products WHERE status = 'hidden'",
          ),
        ) ??
        0;
    final orders = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM orders'),
        ) ??
        0;
    final categories = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories'),
        ) ??
        0;
    final banners = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM banners'),
        ) ??
        0;
    final notifications = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM notifications'),
        ) ??
        0;

    return AdminStats(
      customers: customers,
      shops: shops,
      pendingShops: pendingShops,
      approvedShops: approvedShops,
      suspendedShops: suspendedShops,
      products: products,
      hiddenProducts: hiddenProducts,
      orders: orders,
      categories: categories,
      banners: banners,
      notifications: notifications,
    );
  }

  // ===========================================================================
  // 12. ENCRYPTED & HMAC-SIGNED SYNC OUTBOX QUEUE
  // ===========================================================================

  /// Enqueues an offline mutation into `sync_outbox` with AES-256-GCM encryption
  /// and an HMAC-SHA256 signature.
  Future<void> enqueueSyncAction({
    required String id,
    required String userId,
    required String actionType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    if (db == null) return;

    await _writeLock.synchronized(() async {
      final createdAtMs = DateTime.now().millisecondsSinceEpoch;
      final encryptedPayload = OfflineSecurityService.instance.encryptMap(
        payload,
      );
      final signature = OfflineSecurityService.instance.signPayload(
        actionType: actionType,
        entityId: entityId,
        encryptedPayload: encryptedPayload,
        createdAtMs: createdAtMs,
      );

      await db.insert(
        'sync_outbox',
        {
          'id': id,
          'user_id': userId,
          'action_type': actionType,
          'entity_id': entityId,
          'encrypted_payload': encryptedPayload,
          'hmac_signature': signature,
          'status': 'pending',
          'retry_count': 0,
          'created_at_ms': createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Retrieves all pending outbox operations ordered chronologically (FIFO),
  /// verifying both the HMAC-SHA256 signature and AES-256-GCM authentication tag.
  Future<List<SyncOutboxRecord>> getPendingSyncActions({String? userId}) async {
    final db = await database;
    if (db == null) return const [];

    final whereClauses = <String>["status IN ('pending', 'failed')"];
    final whereArgs = <Object?>[];
    if (userId != null && userId.isNotEmpty) {
      whereClauses.add('user_id = ?');
      whereArgs.add(userId);
    }

    final rows = await db.query(
      'sync_outbox',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at_ms ASC',
    );

    final records = <SyncOutboxRecord>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final uId = row['user_id']?.toString() ?? '';
      final actionType = row['action_type']?.toString() ?? '';
      final entityId = row['entity_id']?.toString() ?? '';
      final encryptedPayload = row['encrypted_payload']?.toString() ?? '';
      final signature = row['hmac_signature']?.toString() ?? '';
      final status = row['status']?.toString() ?? 'pending';
      final retryCount = (row['retry_count'] as num?)?.toInt() ?? 0;
      final createdAtMs = (row['created_at_ms'] as num?)?.toInt() ?? 0;
      final lastError = row['last_error']?.toString();

      // Verify HMAC-SHA256 integrity signature before trusting the action
      final validSig = OfflineSecurityService.instance.verifyPayloadSignature(
        actionType: actionType,
        entityId: entityId,
        encryptedPayload: encryptedPayload,
        createdAtMs: createdAtMs,
        signature: signature,
      );

      if (!validSig) {
        // Tampered record detected! Quarantine/delete immediately.
        debugPrint(
          '[LocalDatabase] SECURITY ALERT: Tampered sync_outbox row ($id) rejected and removed.',
        );
        await deleteSyncAction(id);
        continue;
      }

      try {
        final decryptedPayload = OfflineSecurityService.instance.decryptMap(
          encryptedPayload,
        );
        records.add(
          SyncOutboxRecord(
            id: id,
            userId: uId,
            actionType: actionType,
            entityId: entityId,
            payload: decryptedPayload,
            encryptedPayload: encryptedPayload,
            hmacSignature: signature,
            status: status,
            retryCount: retryCount,
            createdAtMs: createdAtMs,
            lastError: lastError,
          ),
        );
      } on SecurityTamperException catch (e) {
        debugPrint(
          '[LocalDatabase] SECURITY ALERT: Decryption failed for ($id): $e',
        );
        await deleteSyncAction(id);
      }
    }

    return records;
  }

  Future<int> getPendingSyncCount({String? userId}) async {
    final db = await database;
    if (db == null) return 0;

    if (userId != null && userId.isNotEmpty) {
      return Sqflite.firstIntValue(
            await db.rawQuery(
              "SELECT COUNT(*) FROM sync_outbox WHERE status IN ('pending', 'failed') AND user_id = ?",
              [userId],
            ),
          ) ??
          0;
    }
    return Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM sync_outbox WHERE status IN ('pending', 'failed')",
          ),
        ) ??
        0;
  }

  Future<void> markSyncActionSyncing(String id) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.update(
        'sync_outbox',
        {'status': 'syncing'},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> markSyncActionFailed(String id, String error) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.rawUpdate(
        '''
        UPDATE sync_outbox
        SET status = 'failed', retry_count = retry_count + 1, last_error = ?
        WHERE id = ?
        ''',
        [error, id],
      );
    });
  }

  Future<void> deleteSyncAction(String id) async {
    final db = await database;
    if (db == null) return;
    await _writeLock.synchronized(() async {
      await db.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
    });
  }
}
