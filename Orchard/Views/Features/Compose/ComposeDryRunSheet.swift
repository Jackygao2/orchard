import ComposePlanner
import SwiftUI

struct DryRunPlan: Identifiable {
    let id = UUID()
    let operations: [ComposePlanner.Operation]
}

struct ComposeDryRunSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plan: DryRunPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dry Run").font(.title2.weight(.semibold))
            Text("No changes were made. This plan reflects the current snapshot; Up checks the state again before running.")
                .foregroundStyle(.secondary)
            Divider()
            if plan.operations.isEmpty {
                Text("No operations are needed.")
                    .accessibilityIdentifier("compose-plan-empty")
                Spacer()
            } else {
                List(Array(plan.operations.enumerated()), id: \.offset) { index, operation in
                    Text("\(index + 1). \(operation.summary)")
                        .textSelection(.enabled)
                        .accessibilityIdentifier("compose-plan-operation-\(index)")
                }
                .accessibilityIdentifier("compose-plan-operations")
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560, height: 400)
        .accessibilityIdentifier("compose-dry-run-sheet")
    }
}
