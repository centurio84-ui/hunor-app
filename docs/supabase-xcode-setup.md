# Supabase + Xcode setup

The app code now expects the official Supabase Swift SDK.

## Add the package in Xcode

1. Open the HUNOR iOS project in Xcode.
2. Choose **File → Add Package Dependencies…**
3. Enter:
   https://github.com/supabase/supabase-swift.git
4. Add the **Supabase** product to the HUNOR app target.

The app already contains:
- Supabase project URL and publishable key configuration
- Email/password sign-in
- Profile loading
- Member and skill loading
- Availability loading
- Event loading
- Skill add/remove
- Availability status update

The publishable key is intended for client applications; never put a Supabase secret key/service-role key in the iOS app.

## Required database grants

If the app receives a permission error from the Data API, run the following in Supabase SQL Editor after RLS policies are in place:

```sql
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.skills to authenticated;
grant select, insert, update, delete on public.availability to authenticated;
grant select on public.events to authenticated;
grant select, insert, update on public.event_participants to authenticated;
```
