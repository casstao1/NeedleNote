import SwiftUI

struct ProjectsListView: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var purchases: PurchaseManager
    @State private var showingNewProject = false
    @State private var showingPaywall = false
    @State private var activeProjectID: KnitProject.ID?
    
    var body: some View {
        NavigationStack {
            ZStack {
                KnitTheme.cream.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        HStack(alignment: .center) {
                            Text("Projects")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)

                            Spacer()

                            Button {
                                handleCreateProjectTap()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(KnitTheme.rose)
                                    .clipShape(Circle())
                                    .shadow(color: KnitTheme.rose.opacity(0.22), radius: 10, y: 4)
                            }
                        }
                        .padding(.top, 8)

                        if store.projects.isEmpty {
                            EmptyProjectsState()
                                .padding(.top, 48)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(store.projects) { project in
                                    SwipeableProjectCard(
                                        project: project,
                                        onOpen: {
                                            activeProjectID = project.id
                                        },
                                        onDelete: {
                                            deleteProject(project.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $activeProjectID) { projectID in
                if let project = store.projects.first(where: { $0.id == projectID }) {
                    ProjectDetailView(project: project)
                } else {
                    ZStack {
                        KnitTheme.cream.ignoresSafeArea()
                        Text("Project unavailable")
                            .foregroundColor(KnitTheme.taupe)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewProject) {
            NewProjectView { createdProject in
                showingNewProject = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    activeProjectID = createdProject.id
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView {
                Task { @MainActor in
                    showingPaywall = false
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    showingNewProject = true
                }
            }
        }
    }

    func handleCreateProjectTap() {
        if purchases.canCreateProject(existingProjectCount: store.projects.count) {
            showingNewProject = true
        } else {
            showingPaywall = true
        }
    }

    func deleteProject(_ projectID: KnitProject.ID) {
        store.projects.removeAll { $0.id == projectID }
        if activeProjectID == projectID {
            activeProjectID = nil
        }
        store.save()
    }
}

struct EmptyProjectsState: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KnitTheme.roseLight)
                    .frame(width: 72, height: 72)

                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(KnitTheme.rose)
            }

            VStack(spacing: 6) {
                Text("Start your first project")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(KnitTheme.brown)

                Text("Tap the plus button above to create your free first project.")
                    .font(.system(size: 15))
                    .foregroundColor(KnitTheme.taupe)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .cardStyle()
    }
}

// MARK: - Project Card

struct SwipeableProjectCard: View {
    let project: KnitProject
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var settledOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 84

    var currentOffset: CGFloat {
        min(0, max(-actionWidth, settledOffset + dragOffset))
    }

    var revealedWidth: CGFloat {
        max(0, -currentOffset)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(KnitTheme.warmWhite)
                .shadow(color: KnitTheme.cardShadow, radius: 8, x: 0, y: 2)

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 62)
                        .frame(maxHeight: .infinity)
                        .background(Color(red: 0.84, green: 0.43, blue: 0.43))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
            }
            .background(KnitTheme.cream.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .mask(alignment: .trailing) {
                Rectangle()
                    .frame(width: revealedWidth)
            }

            ProjectCard(project: project)
                .offset(x: currentOffset)
                .onTapGesture {
                    if settledOffset != 0 {
                        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                            settledOffset = 0
                            dragOffset = 0
                        }
                    } else {
                        onOpen()
                    }
                }
                .highPriorityGesture(rowSwipeGesture)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var rowSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation.width
                if translation < 0 || settledOffset < 0 {
                    dragOffset = translation
                }
            }
            .onEnded { value in
                let predicted = settledOffset + value.predictedEndTranslation.width
                let shouldOpen = predicted < (-actionWidth * 0.45)

                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                    settledOffset = shouldOpen ? -actionWidth : 0
                    dragOffset = 0
                }
            }
    }
}

struct ProjectCard: View {
    let project: KnitProject
    
    var body: some View {
        HStack(spacing: 14) {
            projectThumbnail
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(project.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(KnitTheme.brown)
                }
                
                if !project.rowSections.isEmpty {
                    Text("\(project.rowSections.count) sections")
                        .font(.system(size: 13))
                        .foregroundColor(KnitTheme.taupe)
                }
                
                Text("Last worked \(project.lastWorked.relativeString)")
                    .font(.system(size: 12))
                    .foregroundColor(KnitTheme.taupe.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(KnitTheme.roseMid)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardStyle()
    }

    @ViewBuilder
    private var projectThumbnail: some View {
        if let photoData = project.photoData.first,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(KnitTheme.roseMid.opacity(0.5))
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(KnitTheme.rose.opacity(0.5))
                        .rotationEffect(.degrees(180))
                )
        }
    }
}
