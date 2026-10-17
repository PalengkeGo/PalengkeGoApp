import { validateVendorComplaintInput } from '../_shared/complaints.ts'

Deno.test('vendor complaint input trims fields and keeps optional details null', () => {
  const result = validateVendorComplaintInput({
    stallId: ' stall-123 ',
    reason: ' Scam or Fraud ',
    details: '   ',
  })
  if (result.stallId !== 'stall-123' || result.reason !== 'Scam or Fraud' || result.details !== null) {
    throw new Error('Vendor complaint input was not normalized')
  }
})

Deno.test('vendor complaint input rejects empty reasons', () => {
  try {
    validateVendorComplaintInput({ stallId: 'stall-123', reason: '  ' })
  } catch {
    return
  }
  throw new Error('Empty complaint reason was accepted')
})
