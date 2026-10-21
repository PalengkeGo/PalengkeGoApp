import { err } from './errors.ts'

export function validateSupportReportInput(value: unknown): {
  topic: string
  details: string
} {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw err('invalid-argument', 'A support report is required')
  }
  const data = value as Record<string, unknown>
  const topic = typeof data.topic === 'string' ? data.topic.trim() : ''
  const details = typeof data.details === 'string' ? data.details.trim() : ''
  if (!topic || topic.length > 80) {
    throw err('invalid-argument', 'A topic of 1 to 80 characters is required')
  }
  if (!details || details.length > 2000) {
    throw err('invalid-argument', 'A description of 1 to 2000 characters is required')
  }
  return { topic, details }
}
