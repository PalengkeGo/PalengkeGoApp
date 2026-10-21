-- Hosted Supabase defaults can grant anon EXECUTE directly, independently of PUBLIC.
REVOKE ALL ON FUNCTION public.chat_uid(), public.chat_role(text),
  public.chat_get_or_create(text,text,text,text), public.chat_send_message(text,text,text,text),
  public.chat_mark_read(text) FROM anon;
