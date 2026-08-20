/* Public browser configuration only. Never place service-role keys in this file. */
window.AP_RETAIL_CONFIG = {
  supabaseUrl: 'https://abtsctwfkgzciseppach.supabase.co',
  supabasePublishableKey: 'sb_publishable_TyJWnKkbS8vKcQKKAzoqSg_BOguwKRv',
  imageBucket: 'store-media'
};

if (!document.querySelector('link[data-retail-motion]')) {
  const motion = document.createElement('link');
  motion.rel = 'stylesheet';
  motion.href = 'shared/retail-motion.css?v=retail-press-v1';
  motion.dataset.retailMotion = 'true';
  document.head.append(motion);
}
