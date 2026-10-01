CREATE OR REPLACE FUNCTION public.save_market_stall(p_uid text, p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path = public AS $$
DECLARE stall_row public.stall_holders%ROWTYPE; schedule_row jsonb;
BEGIN
  SELECT * INTO STRICT stall_row FROM stall_holders WHERE user_id=p_uid FOR UPDATE;
  UPDATE stall_holders SET stall_name=p_data->>'stall_name', description=p_data->>'description',
    category=p_data->>'category', stall_number=COALESCE(NULLIF(p_data->>'stall_number',''), stall_number),
    floor_number=COALESCE(NULLIF(p_data->>'floor_number',''), floor_number),
    is_open=(p_data->>'is_open')::boolean,
    banner_image_url=p_data->>'banner_image_url', avatar_image_url=p_data->>'avatar_image_url',
    thumbnail_url=p_data->>'thumbnail_url' WHERE stall_holder_id=stall_row.stall_holder_id
    RETURNING * INTO stall_row;
  IF p_data ? 'schedule' THEN
    DELETE FROM stall_holder_schedule WHERE stall_holder_id=stall_row.stall_holder_id;
    FOR schedule_row IN SELECT value FROM jsonb_array_elements(p_data->'schedule') LOOP
      INSERT INTO stall_holder_schedule(stall_holder_id,day_of_week,opening_time,closing_time,is_closed)
      VALUES(stall_row.stall_holder_id,schedule_row->>'name',(schedule_row->>'openTime')::time,
        (schedule_row->>'closeTime')::time,NOT (schedule_row->>'isOpen')::boolean);
    END LOOP;
  END IF;
  RETURN to_jsonb(stall_row);
END $$;

REVOKE ALL ON FUNCTION public.save_market_stall(text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_market_stall(text,jsonb) TO service_role;
