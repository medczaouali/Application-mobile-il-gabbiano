# Brand palette customization

Centralize your colors in `lib/theme/brand_palette.dart`.

Edit the gradient lists to match your branding:

- `headerGradient`: Dashboard header background.
- `menuGradient`, `reservationsGradient`, `usersGradient`, `ordersGradient`, `reviewsGradient`, `complaintsGradient`: Action cards.
- `glassOnPrimary`: Semi-transparent overlay for icons on gradient backgrounds.
- `softShadow`: Modern depth shadow shared by cards.

After updating, rebuild the app — the Admin Dashboard will automatically reflect your new palette.

Tip: Prefer accessible contrast. Check text legibility on gradients (white text over bright gradients usually works well).