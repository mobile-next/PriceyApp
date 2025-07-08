import Foundation

struct TokenCounts {
	let inputTokens: Int64
	let outputTokens: Int64
	let cacheCreationTokens: Int64
	let cacheReadTokens: Int64
	
	static let zero = TokenCounts(inputTokens: 0, outputTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0)
	
	static func +(lhs: TokenCounts, rhs: TokenCounts) -> TokenCounts {
		return TokenCounts(
			inputTokens: lhs.inputTokens + rhs.inputTokens,
			outputTokens: lhs.outputTokens + rhs.outputTokens,
			cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
			cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens
		)
	}
}