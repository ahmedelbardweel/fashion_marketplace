# Shop product editor

The editor uses four steps: basics, media, stock options, and review. Optional brand, material, care and internal SKU are persisted in products.details. Customer details expose brand/material/care. Category names entered by an approved shop are created (or reused case-insensitively) in the shared catalog when the product is saved.

## Deployment order

Apply `supabase/migrations/012_shop_product_editor.sql` before releasing this client. The new `shop_save_product_form` RPC saves the product, category, options and ordered image associations in one transaction. The migration has been tested locally; it is not applied to the hosted database by these source changes.

Existing options retain their IDs; removed options become inactive with zero stock to preserve order references. Image removals affect product associations, not storage objects. Existing image URLs are retained and their ordering is loaded and saved. The first gallery image is the cover. Images are limited to 12 and options to 200.

Image selection starts background removal automatically, then uploads PNG bytes. The user sees an immediate local preview, processing state, and retry/delete controls for each failed image. Failed processing never silently uploads the original, and saving waits for all included images to finish. Cancellation/disposal ignores late callbacks. The native background-removal model still needs an actual-device quality check; widget tests mock inference and storage.

## Validation

- `flutter test test/shop/product_editor_test.dart test/loading test/virtual_tryon`
- `node test/shop/product_editor_sql_test.cjs` with `PGLITE_MODULE` set to an installed `@electric-sql/pglite` module.

SQL tests cover atomic rollback, ownership, category reuse, variant retirement, image replacement/order and publish validation. Widget tests cover a narrow RTL editor with larger text, category draft saving, automatic image processing and failure recovery.
