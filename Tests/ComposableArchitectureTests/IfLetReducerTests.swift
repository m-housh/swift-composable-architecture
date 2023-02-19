import ComposableArchitecture
import XCTest

@MainActor
final class IfLetReducerTests: XCTestCase {
  #if DEBUG
    func testNilChild() async {
      let store = TestStore(
        initialState: Int?.none,
        reducer: EmptyReducer<Int?, Void>()
          .ifLet(\.self, action: /.self) {}
      )

      XCTExpectFailure {
        $0.compactDescription == """
            An "ifLet" at "\(#fileID):\(#line - 5)" received a child action when child state was \
            "nil". …

              Action:
                ()

            This is generally considered an application logic error, and can happen for a few \
            reasons:

            • A parent reducer set child state to "nil" before this reducer ran. This reducer must \
            run before any other reducer sets child state to "nil". This ensures that child \
            reducers can handle their actions while their state is still available.

            • An in-flight effect emitted this action when child state was "nil". While it may be \
            perfectly reasonable to ignore this action, consider canceling the associated effect \
            before child state becomes "nil", especially if it is a long-living effect.

            • This action was sent to the store while state was "nil". Make sure that actions for \
            this reducer can only be sent from a view store when state is non-"nil". In SwiftUI \
            applications, use "IfLetStore".
            """
      }

      await store.send(())
    }
  #endif

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  func testEffectCancellation() async {
    struct Child: ReducerProtocol {
      struct State: Equatable {
        var count = 0
      }
      enum Action: Equatable {
        case timerButtonTapped
        case timerTick
      }
      @Dependency(\.continuousClock) var clock
      func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
        case .timerButtonTapped:
          return .run { send in
            for await _ in self.clock.timer(interval: .seconds(1)) {
              await send(.timerTick)
            }
          }
        case .timerTick:
          state.count += 1
          return .none
        }
      }
    }
    struct Parent: ReducerProtocol {
      struct State: Equatable {
        var child: Child.State?
      }
      enum Action: Equatable {
        case child(Child.Action)
        case childButtonTapped
      }
      var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
          switch action {
          case .child:
            return .none
          case .childButtonTapped:
            state.child = state.child == nil ? Child.State() : nil
            return .none
          }
        }
        .ifLet(\.child, action: /Action.child) {
          Child()
        }
      }
    }
    await _withMainSerialExecutor {
      let clock = TestClock()
      let store = TestStore(
        initialState: Parent.State(),
        reducer: Parent()
      ) {
        $0.continuousClock = clock
      }
      await store.send(.childButtonTapped) {
        $0.child = Child.State()
      }
      await store.send(.child(.timerButtonTapped))
      await clock.advance(by: .seconds(2))
      await store.receive(.child(.timerTick)) {
        try (/.some).modify(&$0.child) {
          $0.count = 1
        }
      }
      await store.receive(.child(.timerTick)) {
        try (/.some).modify(&$0.child) {
          $0.count = 2
        }
      }
      await store.send(.childButtonTapped) {
        $0.child = nil
      }
    }
  }
}
