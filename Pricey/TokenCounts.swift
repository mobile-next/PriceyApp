import Foundation

struct ModelUsage {
	let inputTokens: Int64
	let outputTokens: Int64
	let cacheCreationTokens: Int64
	let cacheReadTokens: Int64
	
	static let zero = ModelUsage(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0)
	
	static func +(lhs: ModelUsage, rhs: ModelUsage) -> ModelUsage {
		return ModelUsage(
			inputTokens: lhs.inputTokens + rhs.inputTokens,
			outputTokens: lhs.outputTokens + rhs.outputTokens,
			cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
			cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens
		)
	}
}

struct UsageStat {
	let inputTokens: Int64
	let outputTokens: Int64
	let cacheCreationTokens: Int64
	let cacheReadTokens: Int64
	let linesAdded: Int64
	let linesRemoved: Int64
	let userPrompts: Int64
	let modelUsage: [String: ModelUsage]
	
	static let zero = UsageStat(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, linesAdded: 0, linesRemoved: 0, userPrompts: 0, modelUsage: [:])
	
	static func +(lhs: UsageStat, rhs: UsageStat) -> UsageStat {
		var combinedModelUsage = lhs.modelUsage
		for (model, usage) in rhs.modelUsage {
			combinedModelUsage[model] = (combinedModelUsage[model] ?? ModelUsage.zero) + usage
		}
		
		return UsageStat(
			inputTokens: lhs.inputTokens + rhs.inputTokens,
			outputTokens: lhs.outputTokens + rhs.outputTokens,
			cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
			cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
			linesAdded: lhs.linesAdded + rhs.linesAdded,
			linesRemoved: lhs.linesRemoved + rhs.linesRemoved,
			userPrompts: lhs.userPrompts + rhs.userPrompts,
			modelUsage: combinedModelUsage
		)
	}
}

// Legacy alias for backwards compatibility
typealias TokenCounts = UsageStat