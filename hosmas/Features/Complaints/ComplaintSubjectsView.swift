//
//  ComplaintSubjectsView.swift
//  hosmas
//
//  First real read screen. The list is served from cache on relaunch and
//  refetched in the background, so a cold launch is not a spinner.
//

import SwiftUI
import HosKhas

struct ComplaintSubjectsView: View {
    @Bindable var model: ComplaintSubjectsModel

    var body: some View {
        NavigationStack {
            List(model.headers, id: \.id) { header in
                Section(header.header) {
                    ForEach(header.subjects, id: \.subjectID) { subject in
                        Text(subject.subject)
                    }
                }
            }
            .overlay {
                if model.isLoading { ProgressView() }
                else if let errorMessage = model.errorMessage {
                    ContentUnavailableView("Couldn't load", systemImage: "wifi.slash",
                                           description: Text(errorMessage))
                }
            }
            .navigationTitle("Complaints")
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }
}
