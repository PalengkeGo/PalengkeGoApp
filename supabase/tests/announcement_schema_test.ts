// Run: npx --yes --package=deno deno test --allow-read --allow-env supabase/tests/announcement_schema_test.ts
import { PGlite } from 'npm:@electric-sql/pglite@0.3.14'
import { strict as assert } from 'node:assert'

Deno.test('announcement repair preserves existing rows and supports popup image lists', async () => {
  const db = new PGlite()
  try {
    await db.exec(`CREATE TABLE system_announcements (title text);
      INSERT INTO system_announcements VALUES ('Existing announcement');
      CREATE PUBLICATION supabase_realtime;`)
    const repair = await Deno.readTextFile(new URL(
      '../migrations/20261021050000_repair_popup_announcement_columns.sql', import.meta.url))
    await db.exec(repair)
    await db.exec(repair)
    const old = (await db.query('SELECT * FROM system_announcements')).rows[0]
    assert.deepEqual(old, {title: 'Existing announcement', image_url: null,
      show_as_popup: false, facebook_url: null, popup_image_urls: []})
    await db.query(`INSERT INTO system_announcements(title,show_as_popup,popup_image_urls)
      VALUES ('Popup',true,$1::jsonb)`, [JSON.stringify(['https://example.com/image.jpg'])])
    const popup = (await db.query<{popup_image_urls: string[]}>(
      "SELECT popup_image_urls FROM system_announcements WHERE title='Popup'")).rows[0]
    assert.deepEqual(popup.popup_image_urls, ['https://example.com/image.jpg'])
  } finally {
    await db.close()
  }
})
