//
//  ProfileView.swift
//  hosmas
//
//  Landing screen. userProfile needs only the community token, so a populated
//  screen here means the whole login chain produced a usable session.
//

import SwiftUI
import HosKhas

struct ProfileView: View {
    @Bindable var model: ProfileModel
    /// Called after the session is cleared, so the root can return to login.
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let resident = model.resident {
                    identity(resident)
                }
                if let academics = model.academics {
                    academicsSection(academics)
                }
                if let summary = model.summary {
                    summarySection(summary)
                }
                if !model.roommates.isEmpty {
                    Section("Room-mates") {
                        ForEach(model.roommates) { roommate in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(roommate.name)
                                if let email = roommate.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await model.signOut()
                            onSignOut()
                        }
                    }
                }
            }
            .overlay {
                if model.isLoading && model.profile == nil {
                    ProgressView()
                } else if let errorMessage = model.errorMessage, model.profile == nil {
                    ContentUnavailableView(
                        "Couldn't load profile",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text(errorMessage)
                    )
                }
            }
            .navigationTitle("Profile")
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }

    @ViewBuilder
    private func identity(_ resident: UserProfileResponse.Resident) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(resident.name).font(.title2).bold()
                if let room = model.room {
                    Label(room, systemImage: "bed.double")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            if let email = resident.email {
                LabeledContent("Email", value: email)
            }
            if let contact = resident.contactNo {
                LabeledContent("Phone", value: String(contact))
            }
            if let status = resident.residenceStatusText {
                LabeledContent("Status", value: status.capitalized)
            }
        }
    }

    @ViewBuilder
    private func academicsSection(_ academics: UserProfileResponse.AcademicDetail) -> some View {
        Section("Academics") {
            if let course = academics.courseName, let branch = academics.branchName {
                LabeledContent("Programme", value: "\(course) \(branch)")
            }
            if let year = academics.courseYear {
                LabeledContent("Year", value: String(year))
            }
            if let cgpa = academics.cgpa {
                LabeledContent("CGPA", value: String(format: "%.2f", cgpa))
            }
        }
    }

    @ViewBuilder
    private func summarySection(_ summary: UserProfileResponse.Summary) -> some View {
        Section("Activity") {
            LabeledContent("Complaints", value: String(summary.totalComplaints ?? 0))
            LabeledContent("Bookings", value: String(summary.totalBookings ?? 0))
            LabeledContent("Gate passes", value: String(summary.totalGatePass ?? 0))
        }
    }
}
