import Foundation

struct ClaudePricing {
	let inputTokenCostPer1: Double
	let outputTokenCostPer1: Double
	let cacheCreationTokenCostPer1: Double
	let cacheReadTokenCostPer1: Double
	
	static let `default` = ClaudePricing(
		inputTokenCostPer1: 3.0 / 1_000_000,
		outputTokenCostPer1: 15.0 / 1_000_000,
		cacheCreationTokenCostPer1: 3.75 / 1_000_000,
		cacheReadTokenCostPer1: 0.30 / 1_000_000
	)
	
	static func pricing(for modelName: String) -> ClaudePricing {
		switch modelName {
		case "claude-3-haiku-20240307":
			return ClaudePricing(
				inputTokenCostPer1: 2.5e-07,
				outputTokenCostPer1: 1.25e-06,
				cacheCreationTokenCostPer1: 3e-07,
				cacheReadTokenCostPer1: 3e-08
			)
		case "claude-3-5-haiku-20241022":
			return ClaudePricing(
				inputTokenCostPer1: 8e-07,
				outputTokenCostPer1: 4e-06,
				cacheCreationTokenCostPer1: 1e-06,
				cacheReadTokenCostPer1: 8e-08
			)
		case "claude-3-5-haiku-latest":
			return ClaudePricing(
				inputTokenCostPer1: 1e-06,
				outputTokenCostPer1: 5e-06,
				cacheCreationTokenCostPer1: 1.25e-06,
				cacheReadTokenCostPer1: 1e-07
			)
		case "claude-3-opus-latest", "claude-3-opus-20240229":
			return ClaudePricing(
				inputTokenCostPer1: 1.5e-05,
				outputTokenCostPer1: 7.5e-05,
				cacheCreationTokenCostPer1: 1.875e-05,
				cacheReadTokenCostPer1: 1.5e-06
			)
		case "claude-3-sonnet-20240229":
			return ClaudePricing(
				inputTokenCostPer1: 3e-06,
				outputTokenCostPer1: 1.5e-05,
				cacheCreationTokenCostPer1: 3.75e-06,
				cacheReadTokenCostPer1: 3e-07
			)
		case "claude-3-5-sonnet-latest", "claude-3-5-sonnet-20240620", "claude-3-5-sonnet-20241022":
			return ClaudePricing(
				inputTokenCostPer1: 3e-06,
				outputTokenCostPer1: 1.5e-05,
				cacheCreationTokenCostPer1: 3.75e-06,
				cacheReadTokenCostPer1: 3e-07
			)
		case "claude-opus-4-20250514", "claude-4-opus-20250514":
			return ClaudePricing(
				inputTokenCostPer1: 1.5e-05,
				outputTokenCostPer1: 7.5e-05,
				cacheCreationTokenCostPer1: 1.875e-05,
				cacheReadTokenCostPer1: 1.5e-06
			)
		case "claude-sonnet-4-20250514", "claude-4-sonnet-20250514":
			return ClaudePricing(
				inputTokenCostPer1: 3e-06,
				outputTokenCostPer1: 1.5e-05,
				cacheCreationTokenCostPer1: 3.75e-06,
				cacheReadTokenCostPer1: 3e-07
			)
		case "claude-3-7-sonnet-latest", "claude-3-7-sonnet-20250219":
			return ClaudePricing(
				inputTokenCostPer1: 3e-06,
				outputTokenCostPer1: 1.5e-05,
				cacheCreationTokenCostPer1: 3.75e-06,
				cacheReadTokenCostPer1: 3e-07
			)
		default:
			return ClaudePricing(
				inputTokenCostPer1: 0.0,
				outputTokenCostPer1: 0.0,
				cacheCreationTokenCostPer1: 0.0,
				cacheReadTokenCostPer1: 0.0
			)
		}
	}
}