-- Check current users in the system and their roles
SELECT 
    id,
    email,
    username,
    role,
    is_member,
    approval_status,
    is_approved,
    created_at
FROM public.users
ORDER BY created_at DESC;