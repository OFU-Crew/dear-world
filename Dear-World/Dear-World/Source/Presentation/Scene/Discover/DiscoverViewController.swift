//
//  DiscoverViewController.swift
//  Dear-World
//
//  Created by dongyoung.lee on 2020/12/25.
//

import ReactorKit
import RxCocoa
import RxSwift
import SnapKit
import Then
import UIKit

final class DiscoverViewController: UIViewController, View {
  typealias Model = Message.Model
  typealias Reactor = DiscoverReactor
  typealias Action = Reactor.Action
  
  // MARK: 🖼 UI
  private let messageCountBadgeView: MessageCountBadgeView = MessageCountBadgeView()
  private let filterView: UIView = UIView()
  private let countryLabel: UILabel = UILabel()
  private let messageTableView: UITableView = UITableView(frame: .null, style: .grouped)
  private let aboutButton: UIButton = UIButton()
  private let sortView: UIView = UIView()
  private var sortLabel: UILabel = UILabel()
  private var messages: [Message.Model.Message] = []
  private let filterContainerView: UIView = UIView()
  private let refreshControl: UIRefreshControl = UIRefreshControl()
  private let messageEmptyView: UIStackView = UIStackView()
  
  var disposeBag: DisposeBag = DisposeBag()
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupUI()
    setupTableView()
    startInitAnimation()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    reactor?.action.onNext(.viewWillAppear)
  }
  
  private func startInitAnimation() {
    animate(view: messageCountBadgeView, alpha: 0.4, length: 20, duration: 0.4)
    animate(view: filterView, alpha: 0.4, length: 20, duration: 0.4)
  }
  
  private func animate(view: UIView, alpha: CGFloat, length: CGFloat, duration: Double, delay: Double = 0) {
    view.alpha = alpha
    view.frame.origin.y += length
    UIView.animate(withDuration: duration) {
      view.alpha = 1
      view.frame.origin.y -= length
    }
  }
  
  // MARK: 🎛 Setup
  private func setupUI() {
    self.view.backgroundColor = .breathingWhite
    
    messageTableView.do {
      $0.backgroundColor = .breathingWhite
    }
    self.view.addSubview(self.messageTableView)
    self.messageTableView.snp.makeConstraints {
      $0.top.bottom.trailing.leading.equalTo(self.view.safeAreaLayoutGuide)
    }
    
    messageEmptyView.do {
      $0.axis = .vertical
      $0.spacing = 25
    }
    self.view.addSubview(self.messageEmptyView)
    messageEmptyView.snp.makeConstraints {
      $0.center.equalToSuperview()
    }
    let emptyImageView: UIImageView = UIImageView().then {
      $0.image = UIImage(named: "empty_message")
    }
    let emptyMessageLabel: UILabel = UILabel().then {
      $0.numberOfLines = 0
      $0.text = "Sorry..\nThere is no message yet.."
      $0.textAlignment = .center
      $0.textColor = .warmBlue
      $0.font = .boldSystemFont(ofSize: 16)
    }
    messageEmptyView.addArrangedSubview(emptyImageView)
    messageEmptyView.addArrangedSubview(emptyMessageLabel)
    
    filterContainerView.do {
      $0.backgroundColor = .breathingWhite
    }
    messageTableView.addSubview(filterContainerView)
    filterContainerView.snp.makeConstraints {
      $0.trailing.leading.equalToSuperview()
      $0.height.equalTo(50)
      $0.centerX.equalToSuperview()
      $0.top.equalToSuperview().inset(109)
      $0.top.greaterThanOrEqualTo(self.view.safeAreaLayoutGuide)
    }
    // 나라 필터링 뷰
    filterContainerView.addSubview(self.filterView)
    self.filterView.snp.makeConstraints {
      $0.leading.equalToSuperview().inset(20)
      $0.centerY.equalToSuperview()
      $0.height.equalTo(20)
    }
    countryLabel.do {
      $0.font = .boldSystemFont(ofSize: 16)
      $0.textColor = .warmBlue
    }
    filterView.addSubview(countryLabel)
    countryLabel.snp.makeConstraints {
      $0.centerY.equalToSuperview()
      $0.leading.equalTo(filterView.snp.leading)
      $0.width.lessThanOrEqualTo(200)
    }
    let select: UIImageView = UIImageView().then {
      $0.image = UIImage(named: "select")
    }
    filterView.addSubview(select)
    select.snp.makeConstraints {
      $0.centerY.equalToSuperview()
      $0.width.equalTo(14)
      $0.height.equalTo(8)
      $0.trailing.equalTo(filterView.snp.trailing)
      $0.leading.equalTo(countryLabel.snp.trailing).offset(5)
    }
    
    // 소트 뷰
    filterContainerView.addSubview(sortView)
    sortView.snp.makeConstraints {
      $0.centerY.equalToSuperview()
      $0.trailing.equalToSuperview().inset(23)
    }
    self.sortLabel.do {
      $0.text = "Recent"
      $0.textColor = .warmBlue
      $0.font = .systemFont(ofSize: 12)
    }
    sortView.addSubview(sortLabel)
    sortLabel.snp.makeConstraints {
      $0.top.leading.bottom.equalToSuperview()
    }
    let sortIcon: UIImageView = UIImageView().then {
      $0.image = UIImage(named: "sort")
    }
    sortView.addSubview(sortIcon)
    sortIcon.snp.makeConstraints {
      $0.trailing.centerY.equalToSuperview()
      $0.size.equalTo(16)
      $0.leading.equalTo(sortLabel.snp.trailing).offset(5)
    }
  }
  
  private func setupTableView() {
    self.messageTableView.do {
      $0.register(MessageTableViewCell.self, forCellReuseIdentifier: "MessageCell")
      $0.delegate = self
      $0.dataSource = self
      $0.showsVerticalScrollIndicator = false
      $0.separatorStyle = .none
      $0.estimatedRowHeight = 200
      $0.rowHeight = UITableView.automaticDimension
      $0.sectionHeaderHeight = 150
      $0.tableHeaderView = nil
      $0.allowsSelection = false
      $0.refreshControl = refreshControl
    }
    
    refreshControl.addTarget(self, action: #selector(tableViewWillRefresh), for: .valueChanged)
  }
  
  @objc private func tableViewWillRefresh() {
    if self.refreshControl.isRefreshing {
      reactor?.action.on(.next(.refresh))
    }
  }
  
  // MARK: 🔗 Bind
  func bind(reactor: Reactor) {
    reactor.action.onNext(.countryDidChanged(.wholeWorld))
    
    reactor.state
      .map(\.messageCount)
      .subscribe(onNext: { [weak self] count in
        self?.messageCountBadgeView.count = count
      })
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$messages)
      .map(\.messages)
      .subscribe(onNext: {[weak self] in
        self?.messages = $0
        self?.messageTableView.reloadData()
      })
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.messageIsEmpty)
      .map { !$0.messageIsEmpty }
      .bind(to: messageEmptyView.rx.isHidden)
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$isPresentAboutPage)
      .map { $0.isPresentAboutPage }
      .filter { $0 }
      .subscribe(onNext: { [weak self] _ in
        let aboutViewController = AboutViewController().then {
          $0.reactor = AboutReactor()
        }
        self?.navigationController?.pushViewController(aboutViewController, animated: true)
      })
      .disposed(by: self.disposeBag)
    
    reactor.state
      .map(\.isRefreshing)
      .distinctUntilChanged()
      .filter { !$0 }
      .subscribe {[weak self] _ in
        self?.messageTableView.refreshControl?.endRefreshing()
      }
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$selectedCountry)
      .map(\.selectedCountry)
      .map { $0?.fullName }
      .bind(to: self.countryLabel.rx.text)
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$selectedCountry)
      .subscribe(onNext: { [weak self] _ in
        self?.messageTableView.setContentOffset(.zero, animated: false)
      })
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$selectedSortType)
      .subscribe(onNext: { [weak self]_ in
        self?.messageTableView.setContentOffset(.zero, animated: false)
      })
      .disposed(by: self.disposeBag)
    
    reactor.state.distinctUntilChanged(\.$isPresentFilter)
      .filter { $0.isPresentFilter }
      .flatMap { [weak self] _ in self?.presentFilter()  ?? .empty() }
      .map { Action.countryDidChanged($0) }
      .bind(to: reactor.action)
      .disposed(by: self.disposeBag)
    
    reactor.state.distinctUntilChanged(\.$isPresentSort)
      .filter { $0.isPresentSort }
      .flatMap { [weak self] _ in self?.presentSort() ?? .empty() }
      .map { Action.sortTypeDidChanged($0) }
      .bind(to: reactor.action)
      .disposed(by: self.disposeBag)
    
    self.messageTableView
      .refreshControl?.rx
      .controlEvent(.valueChanged)
      .map { Action.refresh }
      .bind(to: reactor.action)
      .disposed(by: self.disposeBag)
    
    self.messageTableView
      .rx.isReachedBottom
      .throttle(.milliseconds(300), scheduler: MainScheduler.instance)
      .map { Action.loadMore }
      .bind(to: reactor.action)
      .disposed(by: self.disposeBag)
    
    self.filterView
      .rx.tapGesture()
      .throttle(.milliseconds(300), scheduler: MainScheduler.instance)
      .skip(1)
      .map { _ in Action.tapFilter }
      .bind(to: reactor.action)
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$selectedSortType)
      .map(\.selectedSortType)
      .map(\.title)
      .bind(to: self.sortLabel.rx.text)
      .disposed(by: self.disposeBag)
    
    self.aboutButton.rx.tap
      .throttle(.milliseconds(300), scheduler: MainScheduler.instance)
      .map { Action.tapAbout }
      .bind(to: reactor.action)
      .disposed(by: self.disposeBag)
    
    self.sortView
      .rx.tapGesture()
      .throttle(.milliseconds(300), scheduler: MainScheduler.instance)
      .skip(1)
      .map { _ in Action.tapSort }
      .bind(to: reactor.action)
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$selectedSortType)
      .map(\.selectedSortType)
      .map(\.title)
      .bind(to: self.sortLabel.rx.text)
      .disposed(by: self.disposeBag)
    
    reactor.state
      .distinctUntilChanged(\.$isRefreshing)
      .map(\.isRefreshing)
      .filter { !$0 }
      .bind(to: self.refreshControl.rx.isRefreshing)
      .disposed(by: self.disposeBag)
    
    reactor.state.distinctUntilChanged(\.$shareURL)
      .map { $0.shareURL }
      .subscribe(onNext: { shareURL in
        let shareViewController: UIActivityViewController = UIActivityViewController(
          activityItems: ["🛸우웅🛸\n지구 어디선가 메세지가 도착했어요💌",
                          shareURL],
          applicationActivities: nil
        )
        shareViewController.popoverPresentationController?.sourceView = self.view
        self.present(shareViewController, animated: true)
      })
      .disposed(by: self.disposeBag)
  }
  
  private func presentFilter() -> Observable<Model.Country> {
    guard let reactor = self.reactor else { return .empty() }
    let selected: Model.Country? = reactor.currentState.selectedCountry
    let items: [Model.Country] = reactor.currentState.countries
    let viewController = ItemBottomSheetViewController<Model.Country>().then {
      $0.reactor = ItemBottomSheetReactor(
        items: items,
        selectedItem: selected,
        headerItem: .wholeWorld
      )
      $0.modalPresentationStyle = .overFullScreen
    }
    self.present(viewController, animated: true, completion: nil)
    return viewController.expected.asObservable()
  }
  
  private func presentSort() -> Observable<Model.Sort> {
    guard let reactor = self.reactor else { return .empty() }
    let items: [Model.Sort] = [.recent, .weeklyHot]
    let viewController = ItemBottomSheetViewController<Model.Sort>().then {
      $0.reactor = ItemBottomSheetReactor(
        items: items,
        selectedItem: reactor.currentState.selectedSortType
      )
      $0.modalPresentationStyle = .overFullScreen
    }
    self.present(viewController, animated: true, completion: nil)
    return viewController.expected.asObservable()
  }
}
extension DiscoverViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(
    _ tableView: UITableView,
    willDisplayHeaderView view: UIView,
    forSection section: Int
  ) {
    tableView.bringSubviewToFront(filterContainerView)
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    makeHeaderView()
  }
  
  private func makeHeaderView() -> UIView {
    let headerView: UIView = UIView()
    headerView.backgroundColor = .breathingWhite
    // 상단 메세지 개수 표시 뷰
    headerView.addSubview(self.messageCountBadgeView)
    messageCountBadgeView.snp.makeConstraints {
      $0.centerX.equalToSuperview()
      $0.top.equalToSuperview().inset(16)
    }
    // 어바웃 버튼
    headerView.addSubview(aboutButton)
    aboutButton.do {
      $0.setImage(UIImage(named: "about"), for: .normal)
    }
    aboutButton.snp.makeConstraints {
      $0.size.equalTo(20)
      $0.top.equalToSuperview().inset(20)
      $0.trailing.equalToSuperview().inset(20)
    }
    return headerView
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    self.reactor?.currentState.messages.count ?? 0
  }
  
  func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as? MessageTableViewCell,
          let message = reactor?.currentState.messages[indexPath.row]
    else { return UITableViewCell() }
    cell.configure(message)
    if let reactor = self.reactor {
      cell.shareButton.rx.tap
        .throttle(.milliseconds(300), scheduler: MainScheduler.instance)
        .map { Action.tapShare(at: indexPath.row) }
        .bind(to: reactor.action)
        .disposed(by: self.disposeBag)
    }
    return cell
  }
}

extension Reactive where Base: UIScrollView {
  public var isReachedBottom: ControlEvent<Void> {
    let source = self.contentOffset
      .filter { [weak base = self.base] offset in
        guard let base = base else { return false }
        return base.isReachedBottom(withTolerance: base.frame.height / 2)
      }
      .map { _ in }
    return ControlEvent(events: source)
  }
}

extension UIScrollView {
  func isReachedBottom(withTolerance tolerance: CGFloat = 0) -> Bool {
    guard self.frame.height > 0 else { return false }
    guard self.contentSize.height > 0 else { return false }
    let contentOffsetBottom = self.contentOffset.y + self.frame.height
    return contentOffsetBottom >= self.contentSize.height - tolerance
  }
}
