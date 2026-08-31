import Foundation

/// Events emitted by the barcode scanner seam, separating hardware VisionKit/DataScannerViewController
/// from capture business logic.
public enum BarcodeScannerEvent: Sendable, Equatable {
    case barcodeDetected(String)
    case scanError(String)
    case torchToggled(Bool)
    case sessionStarted
    case sessionStopped
}

/// Protocol defining testable barcode scanner controller / event stream interface.
public protocol BarcodeScannerControlling: Sendable {
    var eventStream: AsyncStream<BarcodeScannerEvent> { get }
    func startScanning() async
    func stopScanning() async
    func setTorchEnabled(_ enabled: Bool) async
}

/// A concrete testable mock or software simulator for BarcodeScannerControlling used in unit tests
/// and non-hardware environments (like simulator or headless checks).
public actor MockBarcodeScannerController: BarcodeScannerControlling {
    public let eventStream: AsyncStream<BarcodeScannerEvent>
    private let continuation: AsyncStream<BarcodeScannerEvent>.Continuation
    private var isScanning = false
    private var torchState = false

    public init() {
        var capturedContinuation: AsyncStream<BarcodeScannerEvent>.Continuation!
        self.eventStream = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    public func startScanning() async {
        isScanning = true
        continuation.yield(.sessionStarted)
    }

    public func stopScanning() async {
        isScanning = false
        continuation.yield(.sessionStopped)
    }

    public func setTorchEnabled(_ enabled: Bool) async {
        torchState = enabled
        continuation.yield(.torchToggled(enabled))
    }

    /// Test helper to simulate scanning a barcode code string.
    public func simulateBarcodeScan(_ code: String) {
        guard isScanning else { return }
        continuation.yield(.barcodeDetected(code))
    }

    /// Test helper to simulate an error.
    public func simulateError(_ message: String) {
        continuation.yield(.scanError(message))
    }
}
