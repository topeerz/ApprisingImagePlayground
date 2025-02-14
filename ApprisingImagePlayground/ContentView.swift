//
//  ContentView.swift
//  ApprisingImagePlayground
//
//  Created by topeerz on 13/02/2025.
//

import ImagePlayground
import Observation
import SwiftUI
import UIKit

// TODO: do somethign cool with PhotosUI

extension Image {
    init(from uiImage: UIImage?) {
        if let uiIimage = uiImage {
            self = Image(uiImage: uiIimage)
            return
        }

        self = Image(systemName: "photo").renderingMode(.template)
    }
}

struct ContentView: View {

    @State private var isPlaygroundRunning = false
    @State private var showingDocumentPicker = false
    @State private var desc = "dreads"
    @State private var generatedImage: UIImage?
    @State private var generatedImageData: Data?
    var placeholderImage = UIImage(systemName: "photo")
    let themeColor = Color(red: 0.6, green: 0.8, blue: 0.9)

    @ViewBuilder
    var body: some View {
        let _ = Self._printChanges()
        // whoa, if some struct or fundamental (bool?) (does it apply to classes though? seems not ...) is NOT in the body then state will (may) get lost when view is re-evaluated ...
        // so it needs to be stored elsewhere or "hacked-in" here (when it may though trigger unnecessary view reevals?)
        // probably Observation + vm may help here ...
        let _ = generatedImageData

        VStack {
            Image(from: generatedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .padding()
                .tint(themeColor)
                .imagePlaygroundSheet(
                    isPresented: $isPlaygroundRunning,
                    concept: desc,
                    sourceImage: nil
                ) { url in
                    guard
                        let data = try? Data(contentsOf: url),
                        let image = UIImage(data: data)
                    else {
                        return
                    }

                    generatedImage = image

                } onCancellation: {
                    desc = ""
                }
            Group {
                Button("generate") {
                    isPlaygroundRunning.toggle()
                }
                Button("save") {
                    guard let generatedImage else { return }

                    Task.detached(priority: .utility) { // pngData seems to be using .utility anwyay ...
                        if let data = generatedImage.pngData() {
                            await MainActor.run {
                                generatedImageData = data
                                showingDocumentPicker = true
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingDocumentPicker) {
                    if let imageData = generatedImageData {
                        DocumentPicker(imageData: imageData)
                    }
                }
            }
            .padding()
            .foregroundStyle(themeColor)
            .fontWeight(.bold)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(themeColor, lineWidth: 3)
            )
        }
    }

    struct DocumentPicker: UIViewControllerRepresentable {
        var imageData: Data

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(
            _ uiViewController: UIDocumentPickerViewController, context: Context
        ) {}

        class Coordinator: NSObject, UIDocumentPickerDelegate {
            var parent: DocumentPicker

            init(_ parent: DocumentPicker) {
                self.parent = parent
            }

            func documentPicker(
                _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
            ) {
                guard let url = urls.first else { return }
                // TODO: avoid priority inversion: pngData shouldn't block UI thread ...
                //                guard let data = parent.imageData else { return }

                let fileurl = uniqueFileName(
                    for: url.appendingPathComponent("image_1.png", conformingTo: .fileURL))

                do {
                    try parent.imageData.write(to: fileurl)
                    print("File saved to: \(fileurl)")

                } catch {
                    print("Error saving file: \(error)")
                }
            }

            func uniqueFileName(for url: URL) -> URL {
                var fileURL = url
                var fileCounter = 1

                while FileManager.default.fileExists(atPath: fileURL.path) {
                    let newFileName = "image_\(fileCounter).png"
                    fileURL = url.deletingLastPathComponent().appendingPathComponent(newFileName)
                    fileCounter += 1
                }

                return fileURL
            }

            func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
                print("User cancelled the document picker")
            }
        }
    }
}

#Preview {
    ContentView()
}
