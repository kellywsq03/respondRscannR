/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The sample app's main view controller that manages the scanning process.
*/

import UIKit
import RoomPlan
import Supabase

class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    
    @IBOutlet var exportButton: UIButton?
    
    @IBOutlet var doneButton: UIBarButtonItem?
    @IBOutlet var cancelButton: UIBarButtonItem?
    @IBOutlet var activityIndicator: UIActivityIndicatorView?
    
    private var isScanning: Bool = false
    
    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureSessionConfig: RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
    
    private var finalResults: CapturedRoom?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up after loading the view.
        setupRoomCaptureView()
        activityIndicator?.stopAnimating()
    }
    
    private func setupRoomCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        
        view.insertSubview(roomCaptureView, at: 0)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ flag: Bool) {
        super.viewWillDisappear(flag)
        stopSession()
    }
    
    private func startSession() {
        isScanning = true
        roomCaptureView?.captureSession.run(configuration: roomCaptureSessionConfig)
        
        setActiveNavBar()
    }
    
    private func stopSession() {
        isScanning = false
        roomCaptureView?.captureSession.stop()
        
        setCompleteNavBar()
    }
    
    // Decide to post-process and show the final results.
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }
    
    // Access the final post-processed results.
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResults = processedResult
        self.exportButton?.isEnabled = true
        self.activityIndicator?.stopAnimating()
    }
    
    @IBAction func doneScanning(_ sender: UIBarButtonItem) {
        if isScanning { stopSession() } else { cancelScanning(sender) }
        self.exportButton?.isEnabled = false
        self.activityIndicator?.startAnimating()
    }

    @IBAction func cancelScanning(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true)
    }
    
    // Export the USDZ output by specifying the `.mesh` export option.
    // Alternatively, `.parametric` exports the model as unit-sized cubes and `.all`
    // exports both in a single USDZ.
    @IBAction func exportResults(_ sender: UIButton) {
        let destinationFolderURL = FileManager.default.temporaryDirectory.appending(path: "Export")
        let fileName = "Room-\(UUID().uuidString).usdz"
        let destinationURL = destinationFolderURL.appending(path: fileName)
        do {
            try finalResults?.export(to: destinationURL, exportOptions: .mesh)

            Task {
                do {
                    guard let supabaseKey = ProcessInfo.processInfo
                        .environment["SUPABASE_KEY"] else {
                        throw NSError(
                            domain: "Supabase",
                            code: 1,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "SUPABASE_KEY environment variable not found"
                            ]
                        )
                    }

                    let supabase = SupabaseClient(
                        supabaseURL: URL(
                            string: "https://ikswhcyfnqipzakncruf.supabase.co"
                        )!,
                        supabaseKey: supabaseKey,
                        options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
                    )

                    // Read the USDZ file
                    let fileData = try Data(contentsOf: destinationURL)

                    // Upload to "assets" bucket
                    try await supabase.storage
                        .from("assets")
                        .upload(
                            fileName,
                            data: fileData,
                            options: FileOptions(
                                contentType: "model/vnd.usdz+zip",
                                upsert: true
                            )
                        )
                    
                    print("Successfully uploaded\(fileName)")

                } catch {
                    print("Supabase error:")
                    print(error)
                }
            }

        } catch {
            print("Error = \(error)")
        }
    }
    
    private func setActiveNavBar() {
        UIView.animate(withDuration: 1.0, animations: {
            self.cancelButton?.tintColor = .white
            self.doneButton?.tintColor = .white
            self.exportButton?.alpha = 0.0
        }, completion: { complete in
            self.exportButton?.isHidden = true
        })
    }
    
    private func setCompleteNavBar() {
        self.exportButton?.isHidden = false
        UIView.animate(withDuration: 1.0) {
            self.cancelButton?.tintColor = .systemBlue
            self.doneButton?.tintColor = .systemBlue
            self.exportButton?.alpha = 1.0
        }
    }
}

