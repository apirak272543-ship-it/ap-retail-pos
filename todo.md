# AP Retail POS — Project TODO

- [ ] Scaffold static MPA web app and GitHub Pages deployment workflow
- [ ] Implement secure Supabase session and store-role gate
- [ ] Implement POS register with server-authoritative sale submission
- [ ] Implement catalog and Golden Rule image upload workflow
- [ ] Implement inventory receipt, adjustment and movement history
- [ ] Implement sales history and receipt detail
- [x] Implement Android WebView shell with published-site allow-list and retry state
- [x] Generate AP Retail POS icon and apply it to Android shell branding
- [x] Add deterministic tests for cart guards and WebView URL policy
- [ ] Verify web, Android shell configuration and cross-app contracts
- [x] Add additive Retail POS schema, server-authoritative sale RPC and append-only inventory audit trail
- [x] Restrict Retail POS SECURITY DEFINER RPCs to authenticated users after advisor audit
- [x] Add Customer retail catalog, isolated cart and server-authoritative delivery checkout pages
- [x] Verify unauthenticated Customer Retail entrypoint on GitHub Pages without rendering fake catalog or financial data
- [x] Phase 7: reconcile POS runtime with live Retail RPC contracts and idempotent sale submission
- [x] Phase 7: add actual inventory movement history without synthetic data
- [x] Phase 7: expand catalog media flow to upload compressed camera/gallery images before persisting image_url
- [x] Phase 7: add sales filtering and receipt-detail behavior only where the server contract provides real data
