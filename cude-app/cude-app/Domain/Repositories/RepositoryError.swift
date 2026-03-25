import Foundation

public enum RepositoryError: Error, LocalizedError {
    case networkError(underlying: Error)
    case parsingError(underlying: Error)
    case timeout
    case unauthorized
    case notFound
    case unexpectedStatusCode(Int)
    case cancelled
    case unknown(underlying: Error)

    public var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .unknown:
            return true
        case .parsingError, .unauthorized, .notFound, .unexpectedStatusCode, .cancelled:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .networkError(let underlying):
            return "网络请求失败: \(underlying.localizedDescription)"
        case .parsingError(let underlying):
            return "数据解析失败: \(underlying.localizedDescription)"
        case .timeout:
            return "请求超时，请稍后重试"
        case .unauthorized:
            return "未授权：请检查登录状态"
        case .notFound:
            return "请求资源不存在"
        case .unexpectedStatusCode(let code):
            return "服务返回异常状态码: \(code)"
        case .cancelled:
            return "请求已取消"
        case .unknown(let underlying):
            return "未知错误: \(underlying.localizedDescription)"
        }
    }

    public static func map(_ error: Error) -> RepositoryError {
        if let repositoryError = error as? RepositoryError {
            return repositoryError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorTimedOut {
            return .timeout
        }

        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled {
            return .cancelled
        }

        return .networkError(underlying: error)
    }
}
