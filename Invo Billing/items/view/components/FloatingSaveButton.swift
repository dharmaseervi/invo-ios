//
//  FloatingSaveButton.swift
//  invo
//
//  Created by dharmaseervi on 11/23/25.
//

import SwiftUI

struct FloatingSaveButton: View {
    @ObservedObject var vm: ItemViewModel
    var dismiss: DismissAction

    var body: some View {
        VStack {
            Button {
                Task {
                    let ok = await vm.createItem()
                    if ok { dismiss() }
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Product")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(vm.isValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!vm.isValid)
            .padding()
        }
    }
}
