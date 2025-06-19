// MARK: - Message Model

import Common


// MARK: - ChatMessageCell
class ChatMessageCell: UITableViewCell {
    static let identifier = "ChatMessageCell"
    
    // MARK: - UI Components
    private lazy var avatarView: UIView = {
        let view = UIView()
        view.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        view.layer.cornerRadius = 12
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor.themColor(named: "ai_icontext1")
        return label
    }()
    
    private lazy var messageBubble: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        return view
    }()
    
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18)
        label.numberOfLines = 0
        label.text = ""
        return label
    }()
    
    private lazy var interruptButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.ag_named("ic_interrput_icon"), for: .normal)
        button.setTitle(ResourceManager.L10n.Conversation.agentInterrputed, for: .normal)
        button.setTitleColor(UIColor.themColor(named: "ai_icontext1"), for: .normal)
        button.setBackgroundColor(color: UIColor.themColor(named: "ai_block4_chat"), forState: .normal)
        button.layer.cornerRadius = 5
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -3, bottom: 0, right: 3)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 3, bottom: 0, right: -3)
        
        button.semanticContentAttribute = .forceLeftToRight
        
        button.isHidden = true
        button.isUserInteractionEnabled = false
        
        button.sizeToFit()
        
        return button
    }()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(avatarView)
        avatarView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(messageBubble)
        contentView.addSubview(interruptButton)
        messageBubble.addSubview(messageLabel)
    }
    
    func configure(with message: Message) {
        if message.isMine {
            setupUserLayout()
            nameLabel.text = ResourceManager.L10n.Conversation.messageYou
            nameLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            avatarImageView.image = UIImage.ag_named("ic_agent_mine_avatar")
            messageLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            messageBubble.backgroundColor = UIColor.themColor(named: "ai_block4_chat")
        } else {
            setupAgentLayout()
            avatarView.backgroundColor = .clear
            avatarImageView.image = UIImage.ag_named("ic_agent_avatar")
            nameLabel.text = AppContext.preferenceManager()?.preference.preset?.displayName ?? ""
            nameLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            messageLabel.textColor = UIColor.themColor(named: "ai_icontext1")
            messageBubble.backgroundColor = .clear
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: message.content, attributes: attributes)
        messageLabel.attributedText = attributedString
        
        let detector = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        detector.string = message.content
        if let language = detector.dominantLanguage {
            let rtlLanguages = ["ar", "fa", "he", "ur"]
            messageLabel.textAlignment = rtlLanguages.contains(language) ? .right : .left
        } else {
            messageLabel.textAlignment = .left
        }
        
        interruptButton.isHidden = !message.isInterrupted
    }
    
    private func setupUserLayout() {
        nameLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-20)
        }
        
        avatarView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.centerY.equalTo(nameLabel)
            make.size.equalTo(CGSize(width: 24, height: 24))
            make.right.equalTo(nameLabel.snp.left).offset(-6)
        }
        
        avatarImageView.snp.remakeConstraints { make in
            make.edges.equalTo(UIEdgeInsets.zero)
        }
        
        messageBubble.snp.remakeConstraints { make in
            make.top.equalTo(avatarView.snp.bottom).offset(8)
            make.right.equalToSuperview().offset(-20)
            make.left.greaterThanOrEqualToSuperview().offset(20)
            make.bottom.lessThanOrEqualToSuperview().offset(-8)
        }
        
        messageLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
    
    private func setupAgentLayout() {
        avatarView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.left.equalToSuperview().offset(20)
            make.size.equalTo(CGSize(width: 24, height: 24))
        }
        
        avatarImageView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 15, height: 10))
        }
        
        nameLabel.snp.remakeConstraints { make in
            make.centerY.equalTo(avatarView)
            make.left.equalTo(avatarView.snp.right).offset(4)
        }
        
        messageBubble.snp.remakeConstraints { make in
            make.top.equalTo(avatarView.snp.bottom).offset(8)
            make.left.equalToSuperview().offset(20)
            make.right.equalTo(-20)
        }
        
        messageLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }
        
        interruptButton.snp.remakeConstraints { make in
            make.left.equalTo(messageBubble)
            make.top.equalTo(messageBubble.snp.bottom)
            make.bottom.equalTo(0)
            make.height.equalTo(22)
        }
    }
}

// MARK: - ChatView
class ChatView: UIView {
    // MARK: - Properties
    lazy var viewModel: ChatMessageViewModel = {
        let vm = ChatMessageViewModel()
        vm.delegate = self
        return vm
    }()
    
    private var shouldAutoScroll = true
    private lazy var arrowButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.ag_named("ic_captions_arrow_icon"), for: .normal)
        button.addTarget(self, action: #selector(clickArrowButton), for: .touchUpInside)
        button.setBackgroundColor(color: UIColor.themColor(named: "ai_block3"), forState: .normal)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.themColor(named: "ai_line1").cgColor
        button.isHidden = true
        return button
    }()
    
    // MARK: - UI Components
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.delegate = self
        table.dataSource = self
        table.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.identifier)
        return table
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupViews() {
        backgroundColor = UIColor.themColor(named: "ai_mask1")
        addSubview(tableView)
        addSubview(arrowButton)
    }
    
    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        arrowButton.snp.makeConstraints { make in
            make.bottom.equalTo(-10)
            make.width.height.equalTo(44)
            make.centerX.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    func getAllMessages() -> [Message] {
        return viewModel.messages
    }
    
    func clearMessages() {
        viewModel.clearMessage()
        tableView.reloadData()
    }
    
    private func scrollToBottom(animated: Bool = true) {
        guard viewModel.messages.count > 0 else { return }
        guard shouldAutoScroll else { return }
        let indexPath = IndexPath(row: viewModel.messages.count - 1, section: 0)
        self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
    
    @objc func clickArrowButton() {
        shouldAutoScroll = true
        arrowButton.isHidden = true
        scrollToBottom()
    }
    
    func getLastMessage(fromUser: Bool) -> Message? {
        return viewModel.messages.last { $0.isMine == fromUser }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension ChatView: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.identifier, for: indexPath) as! ChatMessageCell
        cell.configure(with: viewModel.messages[indexPath.row])
        return cell
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        shouldAutoScroll = false
        arrowButton.isHidden = false
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let isAtBottom = (scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height))
        if isAtBottom {
            shouldAutoScroll = true
            arrowButton.isHidden = true
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

extension ChatView: ChatMessageViewModelDelegate {
    func startNewMessage() {
        tableView.reloadData()
        scrollToBottom()
    }
    
    func messageUpdated() {
        tableView.reloadData()
        if shouldAutoScroll {
            scrollToBottom(animated: true)
        }
    }
    
    func messageFinished() {
        tableView.reloadData()
        scrollToBottom()
    }
}
