-- HUNOR App V1.5: shared device token storage for iOS + Android

alter table public.device_tokens
  drop constraint if exists device_tokens_platform_check;

alter table public.device_tokens
  add constraint device_tokens_platform_check
  check (platform in ('ios', 'android'));

create index if not exists device_tokens_platform_idx
  on public.device_tokens(platform);
