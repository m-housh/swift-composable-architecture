@_spi(Reflection) import CasePaths

extension DependencyValues {
  @usableFromInline
  var navigationID: NavigationID {
    get { self[NavigationIDKey.self] }
    set { self[NavigationIDKey.self] = newValue }
  }
}

private enum NavigationIDKey: DependencyKey {
  static let liveValue = NavigationID()
  static let testValue = NavigationID()
}

@usableFromInline
struct NavigationID: Hashable, Identifiable {
  var path: [AnyHashable] = []

  @usableFromInline
  var id: Self { self }

  @usableFromInline
  func appending<Component>(component: Component) -> Self {
    var navigationID = self
    navigationID.path.append(AnyID(component))
    return navigationID
  }

  @usableFromInline
  func appending(id: AnyID) -> Self {
    var navigationID = self
    navigationID.path.append(id)
    return navigationID
  }

  @usableFromInline
  func appending(path: AnyKeyPath) -> Self {
    var navigationID = self
    navigationID.path.append(path)
    return navigationID
  }
}

extension NavigationID: Sequence {
  public func makeIterator() -> AnyIterator<NavigationID> {
    var id: NavigationID? = self
    return AnyIterator {
      guard var navigationID = id else { return nil }
      defer {
        if navigationID.path.isEmpty {
          id = nil
        } else {
          navigationID.path.removeLast()
          id = navigationID
        }
      }
      return navigationID
    }
  }
}

@usableFromInline
struct AnyID: Hashable, Sendable {
  private var objectIdentifier: ObjectIdentifier
  private var tag: UInt32?
  private var id: AnyHashableSendable?

  @usableFromInline
  init<Base>(_ base: Base) {
    func id(_ identifiable: some Identifiable) -> AnyHashableSendable {
      AnyHashableSendable(identifiable.id)
    }

    self.objectIdentifier = ObjectIdentifier(Base.self)
    self.tag = EnumMetadata(Base.self)?.tag(of: base)
    if let base = base as? any Identifiable {
      self.id = id(base)
    } else if let metadata = EnumMetadata(type(of: base)),
      metadata.associatedValueType(forTag: metadata.tag(of: base)) is any Identifiable.Type
    {
      // TODO: Extract enum payload and assign id
    }
  }
}

private struct AnyHashableSendable: Hashable, @unchecked Sendable {
  let base: AnyHashable

  init<Base: Hashable & Sendable>(_ base: Base) {
    self.base = base
  }
}
