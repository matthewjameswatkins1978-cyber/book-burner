import Foundation

public enum BarcodeScannerEvent: Sendable, Hashable {
    case scanned(isbn: String)
    case torchToggled(isOn: Bool)
    case error(message: String)
}

public protocol BarcodeScannerSeamProtocol: Sendable {
    /// Starts barcode scanning / live data scanner session.
    func startScanning() async throws
    /// Stops barcode scanning session.
    func stopScanning() async
    /// Toggles the hardware torch / flashlight if supported.
    func setTorch(on: Bool) async
    /// Stream of barcode events (scanned ISBNs, errors, torch state changes).
    var eventStream: AsyncStream<BarcodeScannerEvent> { get }
}

public actor MockBarcodeScannerSeam: BarcodeScannerSeamProtocol {
    private var isScanningState = false
    private var torchState = false
    private var continuation: AsyncStream<BarcodeScannerEvent>.Continuation?
    public let eventStream: AsyncStream<BarcodeScannerEvent>

    public init() {
        var capturedContinuation: AsyncStream<BarcodeScannerEvent>.Continuation?
        self.eventStream = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    public func startScanning() async throws {
        isScanningState = true
    }

    public func stopScanning() async {
        isScanningState = false
    }

    public func setTorch(on: Bool) async {
        torchState = on
        continuation?.yield(.torchToggled(isOn: on))
    }

    /// Helper for tests to simulate scanning an ISBN barcode
    public func simulateScan(isbn: String) {
        guard isScanningState else { return }
        continuation?.yield(.scanned(isbn: isbn))
    }

    /// Helper for tests to simulate scanner error
    public func simulateError(message: String) {
        continuation?.yield(.error(message: message))
    }

    public func isScanning() -> Bool {
        return isScanningState
    }

    public func isTorchOn() -> Bool {
        return torchState
    }
}
