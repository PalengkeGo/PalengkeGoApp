import { validateSupportReportInput } from './support_reports.ts'

Deno.test('support report input is trimmed', () => {
  const result = validateSupportReportInput({
    topic: ' App Issue ',
    details: '  Checkout gets stuck.  ',
  })
  if (result.topic !== 'App Issue' || result.details !== 'Checkout gets stuck.') {
    throw new Error('Support report input was not normalized')
  }
})

Deno.test('support report rejects a missing description', () => {
  try {
    validateSupportReportInput({ topic: 'App Issue', details: '   ' })
  } catch {
    return
  }
  throw new Error('Empty support report was accepted')
})
