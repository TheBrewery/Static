import UIKit

public class CustomViewCell: UITableViewCell, CellType {
    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .Default, reuseIdentifier: reuseIdentifier)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
                
//        Remove any old subviews
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
    }
}
