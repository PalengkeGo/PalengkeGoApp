import { strict as assert } from 'node:assert'
import { checkoutError } from '../functions/_shared/errors.ts'

Deno.test('checkout distinguishes stock, piece quantities and internal failures', () => {
  for (const [message, expected] of [
    ['Invalid quantity or insufficient stock', 'current stock'],
    ['Piece quantities must be whole numbers', 'whole numbers'],
    ['This stall is not accepting orders', 'closed or unavailable'],
  ]) {
    const error = checkoutError({code: 'P0001', message})
    assert.equal(error.code, 'failed-precondition')
    assert.ok(error.message.includes(expected))
  }
  const internal = checkoutError({code: '23502', message: 'private database details'})
  assert.equal(internal.code, 'internal')
  assert.ok(!internal.message.includes('private database details'))
})
