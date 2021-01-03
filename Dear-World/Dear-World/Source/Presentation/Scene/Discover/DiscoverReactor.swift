//
//  DiscoverReactor.swift
//  Dear-World
//
//  Created by rookie.w on 2020/12/27.
//

import Foundation
import ReactorKit

final class DiscoverReactor: Reactor {
  enum Action {
    case tapAbout
    case countryDidChanged(country: Message.Model.Country?)
    case refresh
    case loadMore
  }
  
  enum Mutation {
    case setMessages(result: Message.Model.Messages)
    case setRefreshing(Bool)
    case addMessages(result: Message.Model.Messages)
    case setCountry(country: Message.Model.Country?)
    case setLoading(Bool)
    case setPresentAboutPage(Bool)
    case setMessageCount(Int)
  }
  
  struct State {
    var messageCount: Int = 0
    @Revision var selectedCountry: Message.Model.Country?
    @Revision var messages: Message.Model.Messages = .init(firstMsgId: nil, lastMsgId: nil, messageCount: 0, messages: [])
    var isRefreshing: Bool = false
    var isLoading: Bool = false
    var isAnimating: Bool = false
    var currentPage: Int = 1
    @Revision var isPresentAboutPage: Bool = false
  }
  
  var initialState: State
  
  // MARK: 🏁 Initialize
  init() {
    self.initialState = State()
  }
  
  // MARK: 🔫 Mutate
  func mutate(action: Action) -> Observable<Mutation> {
    switch action {
    case let .countryDidChanged(country):
      return .merge(
        Network.request(Message.API.MessageCount(countryCode: country?.code))
          .filterNil()
          .map { Mutation.setMessageCount($0.messageCount) },
          .concat(
          .just(Mutation.setCountry(country: country)),
          .just(.setLoading(true)),
            Network.request(
              Message.API.Messages(
                countryCode: country?.code,
                lastMsgId: nil,
                type: .recent)
            )
            .filterNil()
            .map{ Mutation.setMessages(result: $0) },
          .just(.setLoading(false))
        )
      )
      
    case .refresh:
      return .concat([
        .just(Mutation.setRefreshing(true)),
        .just(Mutation.setRefreshing(false))
      ])
      
    case .loadMore:
      return Observable<Mutation>.concat([
        Network.request(Message.API.Messages(countryCode: currentState.selectedCountry?.code, lastMsgId: currentState.messages.lastMsgId, type: .recent))
          .filterNil()
          .map{ Mutation.addMessages(result: $0) }
      ])
      
    case .tapAbout:
      return .just(.setPresentAboutPage(true))
    }
  }
  
  // MARK: ⚡️ Reduce
  func reduce(state: State, mutation: Mutation) -> State {
    var newState: State = state
    switch mutation {
    case let .setMessages(results):
      newState.messages = results
      newState.currentPage = 1
      
    case let .setRefreshing(flag):
      newState.isRefreshing = flag
    
    case let .addMessages(result: results):
      newState.messages = Message.Model.Messages(firstMsgId: state.messages.firstMsgId, lastMsgId: results.lastMsgId, messageCount: state.messageCount + results.messageCount, messages: currentState.messages.messages + results.messages)
    
    case let .setCountry(country: country):
      newState.selectedCountry = country
    
    case let .setLoading(flag): 
      newState.isLoading = flag
      
    case .setPresentAboutPage(let isPresentAboutPage):
      newState.isPresentAboutPage = isPresentAboutPage
      
    case let .setMessageCount(count):
      newState.messageCount = count
    }
    return newState
  }
}
