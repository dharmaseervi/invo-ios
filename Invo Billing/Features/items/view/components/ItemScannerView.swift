//
//  ItemScannerView.swift
//  Invo Billing
//
//  Created by dharmaseervi on 12/18/25.
//

import AVFoundation
import SwiftUI

struct ItemScannerView: UIViewControllerRepresentable {
    var onCancel: (() -> Void)? = nil
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        vc.onCancel = onCancel
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onScan: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?

    /// Serial queue for session configuration and start/stop. AVCaptureSession.startRunning
    /// blocks until the camera is ready, which freezes the UI if called on the main thread.
    private let sessionQueue = DispatchQueue(label: "scanner.session")

    private var hasScanned = false
    private let reticleView = UIView()
    private var torchButton: UIButton?

    /// The scan window, as a fraction of the screen. Only codes inside this box are read,
    /// so pointing the phone at a shelf of five labelled boxes scans the one being aimed
    /// at rather than whichever the camera happened to notice first.
    private let reticleWidthRatio: CGFloat = 0.78
    private let reticleHeightRatio: CGFloat = 0.34

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(metadataOutput)
        else {
            showCameraUnavailable()
            return
        }
        self.device = device

        session.beginConfiguration()
        session.addInput(input)
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr, .code128, .ean13, .ean8]
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        buildOverlay()

        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        layoutReticle()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTorch(on: false)
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // MARK: - Scan region

    private var reticleRect: CGRect {
        let width = view.bounds.width * reticleWidthRatio
        let height = view.bounds.height * reticleHeightRatio
        return CGRect(
            x: (view.bounds.width - width) / 2,
            y: (view.bounds.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func layoutReticle() {
        let rect = reticleRect
        reticleView.frame = rect

        // Dim everything outside the window, so it reads as "this is what will be read".
        if let dimmer = view.viewWithTag(9001) as? DimmingView {
            dimmer.frame = view.bounds
            dimmer.holeRect = rect
            dimmer.setNeedsDisplay()
        }

        // rectOfInterest is in the capture device's coordinate space, not the view's, so
        // it has to be converted through the preview layer or the window lands somewhere
        // else entirely — usually rotated, because the camera's origin differs.
        if let preview = previewLayer {
            let converted = preview.metadataOutputRectConverted(fromLayerRect: rect)
            sessionQueue.async { [weak self] in
                self?.metadataOutput.rectOfInterest = converted
            }
        }
    }

    // MARK: - Overlay

    private func buildOverlay() {
        let dimmer = DimmingView(frame: view.bounds)
        dimmer.tag = 9001
        dimmer.backgroundColor = .clear
        dimmer.isUserInteractionEnabled = false
        view.addSubview(dimmer)

        reticleView.layer.borderColor = UIColor.white.cgColor
        reticleView.layer.borderWidth = 2
        reticleView.layer.cornerRadius = 12
        reticleView.isUserInteractionEnabled = false
        view.addSubview(reticleView)

        let hint = UILabel()
        hint.text = "Line up one label inside the box"
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.textAlignment = .center
        hint.numberOfLines = 2
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancel)

        let torch = UIButton(type: .system)
        torch.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
        torch.tintColor = .white
        torch.addTarget(self, action: #selector(torchTapped), for: .touchUpInside)
        torch.translatesAutoresizingMaskIntoConstraints = false
        torch.isHidden = !(device?.hasTorch ?? false)
        view.addSubview(torch)
        torchButton = torch

        NSLayoutConstraint.activate([
            cancel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            torch.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            torch.centerYAnchor.constraint(equalTo: cancel.centerYAnchor),
            torch.widthAnchor.constraint(equalToConstant: 44),
            torch.heightAnchor.constraint(equalToConstant: 44),

            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            hint.topAnchor.constraint(equalTo: view.centerYAnchor, constant: view.bounds.height * reticleHeightRatio / 2 + 20),
        ])
    }

    private func showCameraUnavailable() {
        let label = UILabel()
        label.text = "Camera unavailable"
        label.textColor = .white
        label.textAlignment = .center
        label.frame = view.bounds
        view.addSubview(label)
    }

    // MARK: - Controls

    @objc private func cancelTapped() {
        // Without this the screen could only be left by scanning something, so a label
        // that would not read left the user stuck with no way out.
        onCancel?()
        dismiss(animated: true)
    }

    @objc private func torchTapped() {
        guard let device, device.hasTorch else { return }
        setTorch(on: device.torchMode != .on)
    }

    private func setTorch(on: Bool) {
        guard let device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        torchButton?.setImage(
            UIImage(systemName: on ? "flashlight.on.fill" : "flashlight.off.fill"),
            for: .normal
        )
    }

    // MARK: - Capture

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // The delegate keeps firing while the session winds down, and scanning the same
        // label twice would push two lookups.
        guard !hasScanned else { return }

        let codes = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
        guard !codes.isEmpty, let preview = previewLayer else { return }

        // If more than one code is still visible inside the window, take the one nearest
        // its centre — that is the one the user is aiming at. Previously this took
        // whichever the camera reported first, which is arbitrary.
        let target = view.convert(reticleRect.center, to: view)
        let best = codes
            .compactMap { code -> (AVMetadataMachineReadableCodeObject, CGFloat)? in
                guard let transformed = preview.transformedMetadataObject(for: code)
                        as? AVMetadataMachineReadableCodeObject else { return nil }
                return (code, transformed.bounds.center.distance(to: target))
            }
            .min(by: { $0.1 < $1.1 })?.0

        guard let value = best?.stringValue, !value.isEmpty else { return }

        hasScanned = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        setTorch(on: false)

        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }

        onScan?(value)
    }
}

/// Dims everything outside the scan window, so what will be read is unmistakable.
private final class DimmingView: UIView {
    var holeRect: CGRect = .zero

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        ctx.fill(rect)
        ctx.setBlendMode(.clear)
        ctx.addPath(UIBezierPath(roundedRect: holeRect, cornerRadius: 12).cgPath)
        ctx.fillPath()
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x, dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
