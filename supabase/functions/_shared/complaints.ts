import { err } from './errors.ts'

export function validateEvidencePaths(value: unknown, uid: string): string[] {
  if (value === undefined) return []
  if (!Array.isArray(value) || value.length > 5) {
    throw err('invalid-argument', 'Attach no more than 5 evidence images')
  }
  return value.map((item) => {
    if (typeof item !== 'string' || !item.startsWith(`${uid}/reports/`) ||
        item.includes('..') || !/\.(jpg|jpeg|png|webp)$/i.test(item)) {
      throw err('invalid-argument', 'Evidence image path is invalid')
    }
    return item
  })
}

export function validateVendorComplaintInput(value: unknown): {
  stallId: string
  reason: string
  details: string | null
} {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw err('invalid-argument', 'A complaint object is required')
  }
  const data = value as Record<string, unknown>
  const stallId = typeof data.stallId === 'string' ? data.stallId.trim() : ''
  const reason = typeof data.reason === 'string' ? data.reason.trim() : ''
  const details = typeof data.details === 'string' ? data.details.trim() : ''

  if (!stallId || stallId.length > 128) {
    throw err('invalid-argument', 'A valid stallId is required')
  }
  if (!reason || reason.length > 80) {
    throw err('invalid-argument', 'A reason of 1 to 80 characters is required')
  }
  if (details.length > 2000) {
    throw err('invalid-argument', 'Details must be 2000 characters or fewer')
  }

  return { stallId, reason, details: details || null }
}
