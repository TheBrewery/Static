import UIKit

/// Table view data source.
///
/// You should always access this object from the main thread since it talks to UIKit.
public class DataSource: NSObject {

    // MARK: - Properties

    /// The table view that will use this object as its data source.
    public weak var tableView: UITableView? {
        willSet {
            if let tableView = tableView {
                tableView.dataSource = nil
                tableView.delegate = nil
            }

            registeredCellIdentifiers.removeAll()
        }

        didSet {
            assert(NSThread.isMainThread(), "You must access Static.DataSource from the main thread.")
            updateTableView()
        }
    }
    
    private var oldSections: [Section]?
    
    private var indexPaths = [NSIndexPath]()
    
    
    /// Sections to use in the table view.
    
    public var sections: [Section] {
        willSet {
            oldSections = sections
        }
        
        didSet {
            assert(NSThread.isMainThread(), "You must access Static.DataSource from the main thread.")
            refresh()
        }
    }

    /// Section index titles.
    public var sectionIndexTitles: [String]? {
        didSet {
            assert(NSThread.isMainThread(), "You must access Static.DataSource from the main thread.")
            tableView?.reloadData()
        }
    }

    /// Automatically deselect rows after they are selected
    public var automaticallyDeselectRows = true

    private var registeredCellIdentifiers = Set<String>()


    // MARK: - Initializers

    /// Initialize with optional `tableView` and `sections`.
    public init(tableView: UITableView? = nil, sections: [Section]? = nil) {
        assert(NSThread.isMainThread(), "You must access Static.DataSource from the main thread.")

        self.tableView = tableView
        self.sections = sections ?? []

        super.init()

        updateTableView()
    }

    deinit {
        // nil out the table view to ensure the table view data source and delegate niled out
        tableView = nil
    }


    // MARK: - Public

    public func rowAtPoint(point: CGPoint) -> Row? {
        guard let indexPath = tableView?.indexPathForRowAtPoint(point) else { return nil }
        return rowForIndexPath(indexPath)
    }


    // MARK: - Private

    private func updateTableView() {
        guard let tableView = tableView else { return }
        tableView.dataSource = self
        tableView.delegate = self
        refresh()
    }

    private func refresh() {
        refreshRegisteredCells()
        refreshTableSections()
    }

    private func sectionForIndex(index: Int) -> Section? {
        if sections.count <= index {
            assert(false, "Invalid section index: \(index)")
            return nil
        }

        return sections[index]
    }

    private func rowForIndexPath(indexPath: NSIndexPath) -> Row? {
        if let section = sectionForIndex(indexPath.section) {
            let rows = section.rows
            if rows.count >= indexPath.row {
                return rows[indexPath.row]
            }
        }

        assert(false, "Invalid index path: \(indexPath)")
        return nil
    }
    
    private func refreshTableSections() {
        guard let tableView = tableView else { return }
        guard var oldSections = self.oldSections where oldSections.count > 0 else {
            tableView.reloadData()
            return
        }

        let oldSectionCount = oldSections.count
        let newSectionCount = sections.count
        let sectionDelta = newSectionCount - oldSectionCount
        let animation: UITableViewRowAnimation = .Automatic

        tableView.beginUpdates()

        if sectionDelta == 0 {
            var updatedIndexPaths = [NSIndexPath]()
            var insertedIndexPaths = [NSIndexPath]()
            var deletedIndexPaths = [NSIndexPath]()
            
            for (sectionIndex, section) in sections.enumerate() {
                let oldSection = oldSections[sectionIndex]
                
                let endIndexOfOldSection = oldSection.rows.indices.endIndex
                let endIndexOfSection = section.rows.indices.endIndex
                

                if endIndexOfSection < endIndexOfOldSection {
                // The old section has more rows than the new sections so we should delete them
                    let deletes = (endIndexOfSection..<endIndexOfOldSection).map {
                        NSIndexPath(forRow: $0, inSection: sectionIndex)
                    }
                    deletedIndexPaths.appendContentsOf(deletes)
                }
                
                for (rowIndex, row) in section.rows.enumerate() {
                    if oldSection.rows.indices.contains(rowIndex) {
                    // The index path already exists in the table view
                        if !(row === oldSection.rows[rowIndex]) {
                            // The row is not identical to the old row
                            updatedIndexPaths.append(NSIndexPath(forRow: rowIndex, inSection: sectionIndex))
                        }
                    } else {
                        // The index path does not exists in the table view
                        insertedIndexPaths.append(NSIndexPath(forRow: rowIndex, inSection: sectionIndex))
                    }
                }
            }
            
            tableView.deleteRowsAtIndexPaths(deletedIndexPaths, withRowAnimation: animation)
            tableView.reloadRowsAtIndexPaths(updatedIndexPaths, withRowAnimation: animation)
            tableView.insertRowsAtIndexPaths(insertedIndexPaths, withRowAnimation: animation)
        } else {
            if sectionDelta > 0 {
                // Insert sections
                tableView.insertSections(NSIndexSet(indexesInRange: NSMakeRange(newSectionCount - 1, sectionDelta)), withRowAnimation: animation)
            } else {
                // Remove sections
                tableView.deleteSections(NSIndexSet(indexesInRange: NSMakeRange(newSectionCount - 1, -sectionDelta)), withRowAnimation: animation)
            }

            // Reload existing sections
            let commonCount = min(oldSectionCount, newSectionCount)
            tableView.reloadSections(NSIndexSet(indexesInRange: NSMakeRange(0, commonCount)), withRowAnimation: animation)
        }

        tableView.endUpdates()
    }

    private func refreshRegisteredCells() {
        // A table view is required to manipulate registered cells
        guard let tableView = tableView else { return }

        // Filter to only rows with unregistered cells
        let rows = sections.flatMap{ $0.rows }.filter { !self.registeredCellIdentifiers.contains($0.cellIdentifier) }

        for row in rows {
            let identifier = row.cellIdentifier

            // Check again in case there were duplicate new cell classes
            if registeredCellIdentifiers.contains(identifier) {
                continue
            }

            registeredCellIdentifiers.insert(identifier)
            if let nib = row.cellClass.nib() {
                tableView.registerNib(nib, forCellReuseIdentifier: identifier)
            } else {
                tableView.registerClass(row.cellClass, forCellReuseIdentifier: identifier)
            }
        }
    }
}


extension DataSource: UITableViewDataSource {
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sectionForIndex(section)?.rows.count ?? 0
    }

    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let row = rowForIndexPath(indexPath) {
            let tableCell = tableView.dequeueReusableCellWithIdentifier(row.cellIdentifier, forIndexPath: indexPath)

            if let cell = tableCell as? CellType {
                cell.configure(row: row)
            }

            return tableCell
        }

        return UITableViewCell()
    }

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sections.count
    }

    public func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionForIndex(section)?.header?.title
    }

    public func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return sectionForIndex(section)?.header?.view
    }

    public func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionForIndex(section)?.header?.viewHeight ?? UITableViewAutomaticDimension
    }

    public func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return sectionForIndex(section)?.footer?.title
    }

    public func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return sectionForIndex(section)?.footer?.view
    }

    public func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return sectionForIndex(section)?.footer?.viewHeight ?? UITableViewAutomaticDimension
    }
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        guard let customView = sectionForIndex(indexPath.section)?.rows[indexPath.row].customView else {
            return 44
        }
        return customView.frame.height
    }

    public func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return rowForIndexPath(indexPath)?.canEdit ?? false
    }

    public func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        return rowForIndexPath(indexPath)?.editActions.map {
            action in
            let rowAction = UITableViewRowAction(style: action.style, title: action.title) { (_, _) in
                action.selection?()
            }

            // These calls have side effects when setting to nil
            // Setting a background color to nil will wipe out any predefined style
            // Wrapping these in if-lets prevents nil-setting side effects
            if let backgroundColor = action.backgroundColor {
                rowAction.backgroundColor = backgroundColor
            }

            if let backgroundEffect = action.backgroundEffect {
                rowAction.backgroundEffect = backgroundEffect
            }

            return rowAction
        }
    }

    public func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
        guard let sectionIndexTitles = sectionIndexTitles where sectionIndexTitles.count >= sections.count else { return nil }
        return sectionIndexTitles
    }

    public func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        for (i, section) in sections.enumerate() {
            if let indexTitle = section.indexTitle where indexTitle == title {
                return i
            }
        }
        return max(index, sections.count - 1)
    }
}


extension DataSource: UITableViewDelegate {
    public func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return rowForIndexPath(indexPath)?.isSelectable ?? false
    }

    public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if automaticallyDeselectRows {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }

        if let row = rowForIndexPath(indexPath) {
            row.selection?()
        }
    }

    public func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        if let row = rowForIndexPath(indexPath) {
            row.accessory.selection?()
        }
    }
}
