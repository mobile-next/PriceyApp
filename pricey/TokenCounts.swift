import Foundation

struct UsageStat {
	let inputTokens: Int64
	let outputTokens: Int64
	let cacheCreationTokens: Int64
	let cacheReadTokens: Int64
	let linesAdded: Int64
	let linesRemoved: Int64
	
	static let zero = UsageStat(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, linesAdded: 0, linesRemoved: 0)
	
	static func +(lhs: UsageStat, rhs: UsageStat) -> UsageStat {
		return UsageStat(
			inputTokens: lhs.inputTokens + rhs.inputTokens,
			outputTokens: lhs.outputTokens + rhs.outputTokens,
			cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
			cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
			linesAdded: lhs.linesAdded + rhs.linesAdded,
			linesRemoved: lhs.linesRemoved + rhs.linesRemoved
		)
	}
}

// Legacy alias for backwards compatibility
typealias TokenCounts = UsageStat