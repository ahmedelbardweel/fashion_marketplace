# Body measurements and product sizing

The try-on area selector contains a **My measurements** editor with exactly three
inputs: weight (kg), height (cm), and foot length (cm). All three are required when
saving through the editor. Numeric input accepts Latin, Arabic and Persian digits.
No shoe number, shoe system, foot width or body circumferences are requested.

Profiles are stored locally using SharedPreferences under
`body_measurements.v1.<encoded account id>` (or `guest`). They survive reopening
the app and can be edited or deleted from the selector. They are not synchronized
between devices and are not included in the Decart request. Saving errors leave
the editor open. Account changes reload the corresponding local profile. Older
profiles remain readable; extra measurements and shoe numbers are ignored on load
and omitted on the next save. Older profiles without foot length can be completed
in the editor.

The mannequin is a bounded, approximate illustration. Height changes its height,
weight estimates breadth, and foot length adjusts its feet. Drawing and hit testing use the same deformed
paths. No inferred circumference or weight-derived size is persisted or used for
purchase recommendations.

## Product chart

The seller's **Sizes and stock** step includes an optional measurement-chart
editor for every variant size. This uses the existing `products.details` JSON
and existing save RPC; no database migration is required.

```json
{
  "size_chart": {
    "unit": "cm",
    "measurement_type": "body",
    "rows": [
      {"size": "M", "chest": [94, 100], "waist": [78, 86]},
      {"size": "L", "chest": [100, 108], "waist": [86, 96]}
    ]
  }
}
```

These ranges must come from the product/brand chart and describe the customer's
body, not flat garment measurements. All ranges in a row must be supplied and
match inclusively. The chart must include chest for tops, waist and hips for
bottoms, all three for full outfits, or foot length for footwear. Candidates are
ranked by distance from the center of their ranges, then restricted to stocked
sizes. Shoe numbers alone are not converted into foot lengths or other systems.

The seller chart still supports body ranges, but the customer UI does not ask for
additional inputs. Charts requiring other measurements report that the three
inputs cannot determine an accurate size. Footwear charts based on foot length
can still match. Missing charts, no matching size, and matching sizes out of stock
have distinct UI messages. A suggested size is a chart match, not
a guaranteed fit or a medical assessment.

Validation: `flutter test test/virtual_tryon/body_measurements_test.dart
test/virtual_tryon/measurement_editor_test.dart
test/virtual_tryon/body_zone_selector_test.dart
test/virtual_tryon/product_size_chart_editor_test.dart`.
