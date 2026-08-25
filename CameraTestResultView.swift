import SwiftUI

struct CameraTestResultView: View {
    let working: Bool

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: working ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 110))

            Text(working ? "0.5× CAMERA WORKING" : "0.5× CAMERA NOT WORKING")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(working
                 ? "The Ultra-Wide camera was detected, produced a visible image, and successfully captured a photo."
                 : "The Ultra-Wide camera failed one or more basic function checks.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Test Result")
    }
}
