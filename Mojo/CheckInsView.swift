import SwiftUI
import Supabase
import Charts // Keep Charts imported as TrendsView is still used

// MARK: - Data Models


struct CheckInCategory: Identifiable, Codable, Equatable {
    let id: UUID
    let user_id: UUID
    let name: String
    let is_archived: Bool
    let created_at: Date
    let archived_at: Date?

    enum CodingKeys: String, CodingKey {
        case id, user_id, name, is_archived, created_at, archived_at
    }
}

struct CheckIn: Identifiable, Codable, Equatable {
    let id: UUID
    let user_id: UUID
    let category_id: UUID
    let rating: Int
    let date: String
    let created_at: Date
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case category_id
        case rating
        case date
        case created_at
        case note
    }
}

struct CheckInRating: Equatable {
    let categoryId: UUID
    let categoryName: String
    var rating: Int
    var note: String
}

// MARK: - Main CheckInsView

struct CheckInsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var categories: [CheckInCategory] = []
    @State private var todayRatings: [CheckInRating] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingCategoryManager = false
    @State private var showingTrends = false // Keep this state, for potential external navigation
    @State private var selectedDate = Date()
    @State private var hasSubmittedToday = false
    @State private var isEditMode = false
    @State private var historicalCheckIns: [CheckIn] = []

    private var activeCategories: [CheckInCategory] {
        categories.filter { !$0.is_archived }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // The headerView now contains the title AND the "Edit Categories" button
                headerView

                // Date Selector View has been modified for full width and no "Check In For" text
                dateSelectorView
                    .padding(.horizontal) // Apply horizontal padding to the entire HStack

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else {
                    mainContentView
                }
            }
            // Removed .navigationTitle and .toolbar modifiers
            .task {
                await loadInitialData()
            }
            .sheet(isPresented: $showingCategoryManager) {
                CategoryManagerView(categories: $categories)
                    .environmentObject(sessionManager)
            }
            .sheet(isPresented: $showingTrends) {
                TrendsView(categories: activeCategories)
                    .environmentObject(sessionManager)
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Daily Check-In") // Split into two lines for compactness
                .font(.system(size: 18)) // Smaller font size
                .bold()
                .padding(.leading) // Padding for the text title

            Spacer() // Pushes the title to the left and button to the right

            Button(action: {
                showingCategoryManager = true
            }) {
                HStack(spacing: 4) { // Reduced spacing in the button
                    Image(systemName: "pencil.circle.fill")
                    Text("Edit Categories")
                }
            }
            .font(.caption) // Smaller font for the button text
            .tint(.blue)
            .buttonStyle(.borderedProminent)
            .controlSize(.mini) // Make the button smaller
            .padding(.trailing, 10) // Slightly reduced padding for the button
        }
        .padding(.bottom, 8) // Padding for the entire HStack
    }

    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // dateSelectorView is now directly in the main VStack above mainContentView

            if activeCategories.isEmpty {
                emptyStateView
            } else {
                if isEditMode || !hasSubmittedToday {
                    ratingsView
                } else {
                    progressView
                }
            }
        }
    }

    private var dateSelectorView: some View {
        HStack {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? Date()
                Task { await loadRatingsForDate() }
            }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer() // Pushes the left arrow to the left edge

            // Removed "Check-in for" text and calendar icon
            Text(selectedDate, format: .dateTime.month(.wide).day().year()) // More readable date format
                .font(.headline) // Make it more prominent
                .bold()

            Spacer() // Pushes the right arrow to the right edge

            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? Date()
                Task { await loadRatingsForDate() }
            }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))

            Text("No Categories Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add some categories to start tracking your daily well-being")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Add Categories") {
                showingCategoryManager = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Spacer()
        }
        .padding()
    }

    private var ratingsView: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(todayRatings.enumerated()), id: \.element.categoryId) { index, rating in
                        RatingCard(
                            rating: rating,
                            onRatingChanged: { newRating in
                                todayRatings[index].rating = newRating
                            },
                            onNoteChanged: { newNote in
                                todayRatings[index].note = newNote
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }

            submitButton
                .padding(.horizontal)
        }
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("Edit") {
                    isEditMode = true
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                // The "View Trends" button has been removed here
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(todayRatings, id: \.categoryId) { rating in
                        CategoryProgressCard(
                            rating: rating,
                            historicalData: historicalCheckIns.filter { $0.category_id == rating.categoryId },
                            selectedDate: selectedDate
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var submitButton: some View {
        Button(action: {
            Task { await submitRatings() }
        }) {
            Text("Submit Ratings")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(Color.green)
                .cornerRadius(12)
        }
        .disabled(todayRatings.isEmpty || !todayRatings.contains { $0.rating > 0 })
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        isLoading = true
        await loadCategories()
        await loadRatingsForDate()
        await loadHistoricalData()
        isLoading = false
    }

    private func loadCategories() async {
        guard let userId = sessionManager.session?.user.id else {
            errorMessage = "You must be logged in."
            return
        }

        do {
            let fetchedCategories: [CheckInCategory] = try await supabase.from("checkin_categories")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: true)
                .execute()
                .value

            if fetchedCategories.isEmpty {
                await createDefaultCategories()
            } else {
                await MainActor.run {
                    self.categories = fetchedCategories
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            print("Error loading categories: \(error)")
        }
    }

    private func createDefaultCategories() async {
        guard let userId = sessionManager.session?.user.id else { return }

        let defaultCategories = [
            "Relationships", "Work", "Finance", "Nutrition", "Fitness", "Sleep"
        ]

        for categoryName in defaultCategories {
            struct CategoryPayload: Encodable {
                let user_id: UUID
                let name: String
                let is_archived: Bool
            }

            let payload = CategoryPayload(
                user_id: userId,
                name: categoryName,
                is_archived: false
            )

            do {
                let newCategory: CheckInCategory = try await supabase.from("checkin_categories")
                    .insert(payload, returning: .representation)
                    .select()
                    .single()
                    .execute()
                    .value

                await MainActor.run {
                    self.categories.append(newCategory)
                }
            } catch {
                print("Error creating default category \(categoryName): \(error)")
            }
        }
    }

    private func loadRatingsForDate() async {
        guard let userId = sessionManager.session?.user.id else { return }

        let dateString = dateFormatter.string(from: selectedDate)

        do {
            let existingCheckIns: [CheckIn] = try await supabase.from("checkins")
                .select()
                .eq("user_id", value: userId)
                .eq("date", value: dateString)
                .execute()
                .value

            await MainActor.run {
                // Initialize ratings for all active categories
                self.todayRatings = self.activeCategories.map { category in
                    let existingCheckIn = existingCheckIns.first { $0.category_id == category.id }
                    return CheckInRating(
                        categoryId: category.id,
                        categoryName: category.name,
                        rating: existingCheckIn?.rating ?? 0,
                        note: existingCheckIn?.note ?? ""
                    )
                }

                // Check if we have submitted ratings for today
                self.hasSubmittedToday = !existingCheckIns.isEmpty
            }
        } catch {
            print("Error loading ratings: \(error)")
        }
    }

    private func loadHistoricalData() async {
        guard let userId = sessionManager.session?.user.id else { return }

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let startDate = dateFormatter.string(from: thirtyDaysAgo)
        let endDate = dateFormatter.string(from: Date())

        do {
            let fetchedCheckIns: [CheckIn] = try await supabase.from("checkins")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .order("date", ascending: true)
                .execute()
                .value

            await MainActor.run {
                self.historicalCheckIns = fetchedCheckIns
            }
        } catch {
            print("Error loading historical data: \(error)")
        }
    }

    private func submitRatings() async {
        guard let userId = sessionManager.session?.user.id else { return }

        let dateString = dateFormatter.string(from: selectedDate)

        for rating in todayRatings {
            struct CheckInPayload: Encodable {
                let user_id: UUID
                let category_id: UUID
                let rating: Int
                let date: String
                let note: String?
            }

            let payload = CheckInPayload(
                user_id: userId,
                category_id: rating.categoryId,
                rating: rating.rating,
                date: dateString,
                note: rating.note.isEmpty ? nil : rating.note
            )

            do {
                try await supabase.from("checkins")
                    .upsert(payload, onConflict: "user_id,category_id,date")
                    .execute()
            } catch {
                print("Error saving rating for \(rating.categoryName): \(error)")
            }
        }

        await MainActor.run {
            hasSubmittedToday = true
            isEditMode = false
        }

        // Reload historical data to update the progress view
        await loadHistoricalData()
    }
}

// MARK: - Category Progress Card

struct CategoryProgressCard: View {
    let rating: CheckInRating
    let historicalData: [CheckIn]
    let selectedDate: Date

    private var chartData: [ChartDataPoint] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let selectedDateString = dateFormatter.string(from: selectedDate)

        // Convert historicalData to ChartDataPoint
        var points: [ChartDataPoint] = historicalData.map { checkIn in
            ChartDataPoint(
                date: dateFormatter.date(from: checkIn.date) ?? selectedDate,
                rating: checkIn.rating,
                hasData: true
            )
        }
        // If the current rating for selectedDate is not in historicalData, add it
        if rating.rating > 0 && !historicalData.contains(where: { $0.date == selectedDateString }) {
            points.append(ChartDataPoint(
                date: selectedDate,
                rating: rating.rating,
                hasData: true
            ))
        }
        // Sort by date and take the last 30
        points.sort { $0.date < $1.date }
        let last30 = points.suffix(30)
        return Array(last30)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(rating.categoryName)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                HStack(spacing: 8) {
                    Text("\(rating.rating)/8")
                        .font(.title2.bold())
                        .foregroundColor(.blue)

                    if rating.rating <= 3 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if rating.rating >= 7 {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }

            if !rating.note.isEmpty {
                Text(rating.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            // Charts will now throw an error if Charts module is not imported
            #if canImport(Charts)
            if #available(iOS 16.0, *) {
                Chart(chartData) { dataPoint in
                    if dataPoint.hasData {
                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Rating", dataPoint.rating)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Rating", dataPoint.rating)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .chartYScale(domain: 0...8)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .frame(height: 120)
            } else {
                HStack {
                    Text("30-day trend")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
            }
            #else
            HStack {
                Text("30-day trend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Charts not available on this iOS version")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 120)
            #endif
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Rating Card

struct RatingCard: View {
    let rating: CheckInRating
    let onRatingChanged: (Int) -> Void
    let onNoteChanged: (String) -> Void

    @State private var showingNoteField = false
    @State private var selectedValue: Double = 4.0 // Default to middle value

    // Scale configuration for 1-8 rating system
    let scaleMin: Double = 1.0
    let scaleMax: Double = 8.0
    let step: Double = 1.0

    // Labels for each step
    let labels: [String] = ["Terrible", "Poor", "Okay", "Good", "Great", "Excellent", "Amazing", "Perfect"]

    var currentLabel: String {
        let index = Int(selectedValue - scaleMin)
        return labels[min(max(index, 0), labels.count - 1)]
    }

    var fillPercentage: CGFloat {
        CGFloat((selectedValue - scaleMin) / (scaleMax - scaleMin))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category name
            Text(rating.categoryName)
                .font(.headline)
                .foregroundColor(.primary)

            // Purple segmented bar (visual only)
            PurpleSegmentedBar(fillPercentage: .constant(fillPercentage))
                .frame(height: 30)
                .padding(.bottom, 8)

            // New control element below the bar
            HStack {
                Spacer()
                PurpleSliderControl(
                    fillPercentage: fillPercentage,
                    onChange: { newPercentage in
                        let newValue = scaleMin + (Double(newPercentage) * (scaleMax - scaleMin))
                        selectedValue = max(scaleMin, min(scaleMax, newValue))
                        let intValue = Int(selectedValue)
                        onRatingChanged(intValue)
                        if intValue <= 3 || intValue >= 7 {
                            showingNoteField = true
                        }
                    }
                )
                .frame(width: 150, height: 36) // About half the bar width
                Spacer()
            }

            // Label only (no numbers)
            HStack {
                Spacer()
                Text(currentLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            // Note field for extreme values
            if showingNoteField && (Int(selectedValue) <= 3 || Int(selectedValue) >= 7) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Int(selectedValue) <= 3 ? "What's going on?" : "What's going well?")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Add a note...", text: Binding(
                        get: { rating.note },
                        set: { onNoteChanged($0) }
                    ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            // Initialize with current rating
            selectedValue = Double(rating.rating)
        }
    }
}

// MARK: - Purple Segmented Bar (visual only, no drag)
struct PurpleSegmentedBar: View {
    let fillPercentage: Binding<CGFloat>
    
    let numberOfSegments: Int = 8 // Match the 1-8 rating scale
    let segmentSpacing: CGFloat = 2
    
    let barWidth: CGFloat = 300
    let barHeight: CGFloat = 30
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background of the bar (empty state)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: barWidth, height: barHeight)
            
            // Segmented Fill
            HStack(spacing: segmentSpacing) {
                ForEach(0..<numberOfSegments, id: \.self) { index in
                    let segmentFillThreshold = CGFloat(index + 1) / CGFloat(numberOfSegments)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(segmentColor(for: segmentFillThreshold))
                        .opacity(fillPercentage.wrappedValue >= segmentFillThreshold - (0.5 / CGFloat(numberOfSegments)) ? 1.0 : 0.0)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: barWidth, height: barHeight)
            .clipped()
        }
        .frame(width: barWidth, height: barHeight)
    }
    
    func segmentColor(for threshold: CGFloat) -> Color {
        if fillPercentage.wrappedValue >= threshold {
            // Purple gradient from light to dark
            if threshold <= 0.25 { // Light purple (1-2)
                return Color.purple.opacity(0.3)
            } else if threshold <= 0.5 { // Medium light purple (3-4)
                return Color.purple.opacity(0.5)
            } else if threshold <= 0.75 { // Medium purple (5-6)
                return Color.purple.opacity(0.7)
            } else { // Dark purple (7-8)
                return Color.purple
            }
        } else {
            return .clear
        }
    }
}

// MARK: - Purple Slider Control (draggable thumb below bar)
struct PurpleSliderControl: View {
    var fillPercentage: CGFloat // 0...1
    var onChange: (CGFloat) -> Void
    
    @GestureState private var dragOffset: CGFloat = 0
    
    let controlWidth: CGFloat = 150
    let controlHeight: CGFloat = 36
    let thumbWidth: CGFloat = 48
    let thumbHeight: CGFloat = 36
    
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.purple.opacity(0.15))
                .frame(width: controlWidth, height: controlHeight)
            
            // Thumb
            Capsule()
                .fill(Color.white)
                .frame(width: thumbWidth, height: thumbHeight)
                .shadow(radius: 2)
                .overlay(
                    Capsule()
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
                .offset(x: xOffsetForThumb())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragOffset) { value, state, _ in
                            let x = value.translation.width
                            state = x
                        }
                        .onChanged { value in
                            let x = value.location.x - thumbWidth / 2
                            let percent = min(max(x / (controlWidth - thumbWidth), 0), 1)
                            onChange(percent)
                        }
                )
        }
        .frame(width: controlWidth, height: controlHeight)
    }
    
    private func xOffsetForThumb() -> CGFloat {
        (controlWidth - thumbWidth) * fillPercentage
    }
}

// MARK: - Category Manager

struct CategoryManagerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var categories: [CheckInCategory]

    @State private var newCategoryName = ""
    @State private var editingCategory: CheckInCategory?
    @State private var editingName = ""
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: CheckInCategory?

    var body: some View {
        NavigationStack {
            VStack {
                addCategoryView

                List {
                    ForEach(categories) { category in
                        CategoryRow(
                            category: category,
                            onEdit: { editingCategory = category },
                            onArchive: { await archiveCategory(category) },
                            onDelete: { categoryToDelete = category }
                        )
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Edit Category", isPresented: .constant(editingCategory != nil)) {
                TextField("Category name", text: $editingName)
                Button("Save") {
                    Task { await updateCategory() }
                }
                Button("Cancel", role: .cancel) {
                    editingCategory = nil
                }
            }
            .alert("Delete Category", isPresented: .constant(categoryToDelete != nil)) {
                Text("Are you sure you want to delete '\(categoryToDelete?.name ?? "")'? This action cannot be undone.")
                Button("Delete", role: .destructive) {
                    Task { await deleteCategory() }
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            }
            .onChange(of: editingCategory) { oldValue, newValue in
                if let category = newValue {
                    editingName = category.name
                }
            }
        }
    }

    private var addCategoryView: some View {
        HStack {
            TextField("New category name", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)

            Button("Add") {
                Task { await addCategory() }
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    private func addCategory() async {
        guard let userId = sessionManager.session?.user.id else { return }
        guard !newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        struct CategoryPayload: Encodable {
            let user_id: UUID
            let name: String
            let is_archived: Bool
        }

        let payload = CategoryPayload(
            user_id: userId,
            name: newCategoryName.trimmingCharacters(in: .whitespaces),
            is_archived: false
        )

        do {
            let newCategory: CheckInCategory = try await supabase.from("checkin_categories")
                .insert(payload, returning: .representation)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                categories.append(newCategory)
                newCategoryName = ""
            }
        } catch {
            print("Error adding category: \(error)")
        }
    }

    private func updateCategory() async {
        guard let category = editingCategory else { return }
        guard !editingName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        struct UpdatePayload: Encodable {
            let name: String
        }

        let payload = UpdatePayload(name: editingName.trimmingCharacters(in: .whitespaces))

        do {
            let updatedCategory: CheckInCategory = try await supabase.from("checkin_categories")
                .update(payload)
                .eq("id", value: category.id)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                if let index = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[index] = updatedCategory
                }
                editingCategory = nil
            }
        } catch {
            print("Error updating category: \(error)")
        }
    }

    private func archiveCategory(_ category: CheckInCategory) async {
        struct ArchivePayload: Encodable {
            let is_archived: Bool
            let archived_at: Date?
        }

        let payload = ArchivePayload(
            is_archived: !category.is_archived,
            archived_at: category.is_archived ? nil : Date()
        )

        do {
            let updatedCategory: CheckInCategory = try await supabase.from("checkin_categories")
                .update(payload)
                .eq("id", value: category.id)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                if let index = categories.firstIndex(where: { $0.id == category.id }) {
                    categories[index] = updatedCategory
                }
            }
        } catch {
            print("Error archiving category: \(error)")
        }
    }

    private func deleteCategory() async {
        guard let category = categoryToDelete else { return }

        do {
            try await supabase.from("checkin_categories")
                .delete()
                .eq("id", value: category.id)
                .execute()

            await MainActor.run {
                categories.removeAll { $0.id == category.id }
                categoryToDelete = nil
            }
        } catch {
            print("Error deleting category: \(error)")
        }
    }
}

struct CategoryRow: View {
    let category: CheckInCategory
    let onEdit: () -> Void
    let onArchive: () async -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(category.name)
                .foregroundColor(category.is_archived ? .secondary : .primary)

            if category.is_archived {
                Text("(Archived)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Edit") { onEdit() }
                    .buttonStyle(.borderless)

                Button(category.is_archived ? "Unarchive" : "Archive") {
                    Task { await onArchive() }
                }
                .buttonStyle(.borderless)

                Button("Delete") { onDelete() }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Trends View (Kept as is, as requested, just not directly linked from CheckInsView UI)

struct TrendsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    let categories: [CheckInCategory]

    @State private var checkIns: [CheckIn] = []
    @State private var isLoading = true
    @State private var selectedView = "Individual"

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            VStack {
                Picker("View", selection: $selectedView) {
                    Text("Individual").tag("Individual")
                    Text("Combined").tag("Combined")
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    if selectedView == "Individual" {
                        individualChartsView
                    } else {
                        combinedChartView
                    }
                }
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadCheckIns()
            }
        }
    }

    private var individualChartsView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(categories) { category in
                    CategoryTrendChart(
                        category: category,
                        checkIns: checkIns.filter { $0.category_id == category.id }
                    )
                }
            }
            .padding()
        }
    }

    private var combinedChartView: some View {
        ScrollView {
            CombinedTrendChart(categories: categories, checkIns: checkIns)
                .padding()
        }
    }

    private func loadCheckIns() async {
        guard let userId = sessionManager.session?.user.id else { return }

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let startDate = dateFormatter.string(from: thirtyDaysAgo)
        let endDate = dateFormatter.string(from: Date())

        do {
            let fetchedCheckIns: [CheckIn] = try await supabase.from("checkins")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: startDate)
                .lte("date", value: endDate)
                .order("date", ascending: true)
                .execute()
                .value

            await MainActor.run {
                self.checkIns = fetchedCheckIns
                self.isLoading = false
            }
        } catch {
            print("Error loading check-ins: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Chart Components (Kept as is, as requested)

struct CategoryTrendChart: View {
    let category: CheckInCategory
    let checkIns: [CheckIn]

    private var chartData: [ChartDataPoint] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return (0..<30).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: thirtyDaysAgo) ?? Date()
            let dateString = dateFormatter.string(from: date)
            let checkIn = checkIns.first { $0.date == dateString }

            return ChartDataPoint(
                date: date,
                rating: checkIn?.rating ?? 0,
                hasData: checkIn != nil
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.name)
                .font(.headline)
                .foregroundColor(.primary)

            #if canImport(Charts)
            if #available(iOS 16.0, *) {
                Chart(chartData) { dataPoint in
                    if dataPoint.hasData {
                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Rating", dataPoint.rating)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Rating", dataPoint.rating)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .chartYScale(domain: 0...8)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .frame(height: 200)
            } else {
                Text("Charts require iOS 16+")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
            #else
            Text("Charts not available on this iOS version")
                .foregroundColor(.secondary)
                .frame(height: 200)
            #endif
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct CombinedTrendChart: View {
    let categories: [CheckInCategory]
    let checkIns: [CheckIn]

    private var chartData: [CombinedChartDataPoint] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var data: [CombinedChartDataPoint] = []

        for category in categories {
            for dayOffset in 0..<30 {
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: thirtyDaysAgo) ?? Date()
                let dateString = dateFormatter.string(from: date)
                let checkIn = checkIns.first { $0.category_id == category.id && $0.date == dateString }

                if let checkIn = checkIn {
                    data.append(CombinedChartDataPoint(
                        date: date,
                        rating: checkIn.rating,
                        category: category.name
                    ))
                }
            }
        }

        return data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Categories")
                .font(.headline)
                .foregroundColor(.primary)

            #if canImport(Charts)
            if #available(iOS 16.0, *) {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Rating", dataPoint.rating)
                    )
                    .foregroundStyle(by: .value("Category", dataPoint.category))
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Rating", dataPoint.rating)
                    )
                    .foregroundStyle(by: .value("Category", dataPoint.category))
                }
                .chartYScale(domain: 0...8)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .frame(height: 300)
            } else {
                Text("Charts require iOS 16+")
                    .foregroundColor(.secondary)
                    .frame(height: 300)
            }
            #else
            Text("Charts not available on this iOS version")
                .foregroundColor(.secondary)
                .frame(height: 300)
            #endif
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Chart Data Models (Kept as is, as requested)

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rating: Int
    let hasData: Bool
}

struct CombinedChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rating: Int
    let category: String
}

#if DEBUG
struct CheckInsView_Previews: PreviewProvider {
    static var previews: some View {
        return CheckInsViewPreview()
            .environmentObject(MockSessionManager.create())
    }
}

// Simple preview for the new purple segmented bar RatingCard
struct PurpleRatingCard_Previews: PreviewProvider {
    static var previews: some View {
        RatingCard(
            rating: CheckInRating(
                categoryId: UUID(),
                categoryName: "Work",
                rating: 5,
                note: "Had a productive meeting"
            ),
            onRatingChanged: { _ in },
            onNoteChanged: { _ in }
        )
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}

// Preview-specific version with mock data
struct CheckInsViewPreview: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var categories: [CheckInCategory] = [
        CheckInCategory(
            id: UUID(),
            user_id: UUID(),
            name: "Relationships",
            is_archived: false,
            created_at: Date(),
            archived_at: nil
        ),
        CheckInCategory(
            id: UUID(),
            user_id: UUID(),
            name: "Work",
            is_archived: false,
            created_at: Date(),
            archived_at: nil
        ),
        CheckInCategory(
            id: UUID(),
            user_id: UUID(),
            name: "Health",
            is_archived: false,
            created_at: Date(),
            archived_at: nil
        )
    ]
    @State private var todayRatings: [CheckInRating] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCategoryManager = false
    @State private var showingTrends = false // Keep for preview if you need to test TrendsView via other means
    @State private var selectedDate = Date()
    @State private var hasSubmittedToday = false
    @State private var isEditMode = false
    @State private var historicalCheckIns: [CheckIn] = []

    private var activeCategories: [CheckInCategory] {
        categories.filter { !$0.is_archived }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // The headerView now contains the title AND the "Edit Categories" button
                headerView

                // Date Selector View has been modified for full width and no "Check In For" text
                dateSelectorView
                    .padding(.horizontal) // Apply horizontal padding to the entire HStack

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else {
                    mainContentView
                }
            }
            // Removed .navigationTitle and .toolbar for preview too
            .onAppear {
                setupMockData()
            }
            .sheet(isPresented: $showingCategoryManager) {
                CategoryManagerView(categories: $categories)
                    .environmentObject(sessionManager)
            }
            .sheet(isPresented: $showingTrends) {
                TrendsView(categories: activeCategories)
                    .environmentObject(sessionManager)
            }
        }
    }

    private func setupMockData() {
        // Set up mock ratings
        todayRatings = activeCategories.map { category in
            CheckInRating(
                categoryId: category.id,
                categoryName: category.name,
                rating: Int.random(in: 4...8),
                note: category.name == "Work" ? "Had a productive meeting" : ""
            )
        }

        // Set up mock historical data
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        historicalCheckIns = activeCategories.flatMap { category in
            (0..<30).map { dayOffset in
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: thirtyDaysAgo) ?? Date()
                return CheckIn(
                    id: UUID(),
                    user_id: UUID(),
                    category_id: category.id,
                    rating: Int.random(in: 3...8),
                    date: dateFormatter.string(from: date),
                    created_at: date,
                    note: nil
                )
            }
        }

        hasSubmittedToday = true
    }

    // MARK: - Subviews (Updated for Preview)

    private var headerView: some View {
        HStack {
            Text("Daily Check-In") // Split into two lines for compactness
                .font(.system(size: 24)) // Smaller font size
                .bold()
                .padding(.leading)

            Spacer()

            Button(action: {
                showingCategoryManager = true
            }) {
                HStack(spacing: 4) { // Reduced spacing in the button
                    Image(systemName: "pencil.circle.fill")
                    Text("Edit Categories")
                }
            }
            .font(.caption) // Smaller font for the button text
            .tint(.blue)
            .buttonStyle(.borderedProminent)
            .controlSize(.mini) // Make the button smaller
            .padding(.trailing, 10) // Slightly reduced padding for the button
        }
        .padding(.bottom, 8)
    }

    private var mainContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if activeCategories.isEmpty {
                emptyStateView
            } else {
                if isEditMode || !hasSubmittedToday {
                    ratingsView
                } else {
                    progressView
                }
            }
        }
    }

    private var dateSelectorView: some View {
        HStack {
            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? Date()
                // In preview, you might need to manually update based on mock data logic
                // For live app, Task { await loadRatingsForDate() } would be here
            }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(selectedDate, format: .dateTime.month(.wide).day().year())
                .font(.headline)
                .bold()

            Spacer()

            Button(action: {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? Date()
                // In preview, you might need to manually update based on mock data logic
                // For live app, Task { await loadRatingsForDate() } would be here
            }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.6))

            Text("No Categories Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add some categories to start tracking your daily well-being")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Add Categories") {
                showingCategoryManager = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)

            Spacer()
        }
        .padding()
    }

    private var ratingsView: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(todayRatings.enumerated()), id: \.element.categoryId) { index, rating in
                        RatingCard(
                            rating: rating,
                            onRatingChanged: { newRating in
                                todayRatings[index].rating = newRating
                            },
                            onNoteChanged: { newNote in
                                todayRatings[index].note = newNote
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }

            submitButton
                .padding(.horizontal)
        }
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Progress")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("Edit") {
                    isEditMode = true
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                // Removed "View Trends" button for preview too
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(todayRatings, id: \.categoryId) { rating in
                        CategoryProgressCard(
                            rating: rating,
                            historicalData: historicalCheckIns.filter { $0.category_id == rating.categoryId },
                            selectedDate: selectedDate
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var submitButton: some View {
        Button(action: {
            // For preview, you can simulate submission by just changing states
            hasSubmittedToday = true
            isEditMode = false
            // If you had a mock `loadRatingsForDate` you'd call it here
        }) {
            Text("Submit Ratings")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(Color.green)
                .cornerRadius(12)
        }
        .disabled(todayRatings.isEmpty || !todayRatings.contains { $0.rating > 0 })
    }
}

// MARK: - Purple Segmented Bar Preview

struct PurpleSegmentedBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Purple Segmented Bar Examples")
                .font(.headline)
                .padding(.bottom)
            
            VStack(spacing: 15) {
                HStack {
                    Text("Low (2/8):")
                        .frame(width: 80, alignment: .leading)
                    PurpleSegmentedBar(fillPercentage: .constant(0.25))
                }
                
                HStack {
                    Text("Medium (4/8):")
                        .frame(width: 80, alignment: .leading)
                    PurpleSegmentedBar(fillPercentage: .constant(0.5))
                }
                
                HStack {
                    Text("High (6/8):")
                        .frame(width: 80, alignment: .leading)
                    PurpleSegmentedBar(fillPercentage: .constant(0.75))
                }
                
                HStack {
                    Text("Perfect (8/8):")
                        .frame(width: 80, alignment: .leading)
                    PurpleSegmentedBar(fillPercentage: .constant(1.0))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
#endif
