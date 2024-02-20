//
//  HandTracking.swift
//  HandMeasure
//
//  Created by Basuke Suzuki on 2/14/24.
//

import ARKit
import SwiftUI

extension HandAnchor {
    func indexFingerTipJoint() -> HandSkeleton.Joint? {
        guard isTracked,
            let indexFingerTipJoint = handSkeleton?.joint(.indexFingerTip),
            indexFingerTipJoint.isTracked else { return nil }
        return indexFingerTipJoint
    }

    func worldPosition(of joint: HandSkeleton.Joint) -> simd_float3 {
        matrix_multiply(
            originFromAnchorTransform, joint.anchorFromJointTransform
        ).columns.3.xyz
    }
}

extension HandAnchor.Chirality: CaseIterable {
    public static var allCases: [HandAnchor.Chirality] = [.left, .right]
}

extension HandSkeleton {
    public enum FingerName: String, CaseIterable, Identifiable {
        public var id: String { self.rawValue }

        case thumb, indexFinger, middleFinger, ringFinger, littleFinger
    }

    public struct Finger {
        public let name: FingerName
        public let joints: [Joint]

        public var isTracked: Bool {
            joints.contains { $0.isTracked }
        }

        public var isTrackedCompletely: Bool {
            joints.allSatisfy { $0.isTracked }
        }

        public var isThumb: Bool {
            name == .thumb
        }

        private static func jointNames(_ name: FingerName) -> [JointName] {
            switch name {
            case .thumb:
                [.thumbTip, .thumbIntermediateTip, .thumbIntermediateBase]
            case .indexFinger:
                [.indexFingerTip, .indexFingerIntermediateTip, .indexFingerIntermediateBase, .indexFingerKnuckle]
            case .middleFinger:
                [.middleFingerTip, .middleFingerIntermediateTip, .middleFingerIntermediateBase, .middleFingerKnuckle]
            case .ringFinger:
                [.ringFingerTip, .ringFingerIntermediateTip, .ringFingerIntermediateBase, .ringFingerKnuckle]
            case .littleFinger:
                [.littleFingerTip, .littleFingerIntermediateTip, .littleFingerIntermediateBase, .littleFingerKnuckle]
            }
        }

        init(name: FingerName, from skeleton: HandSkeleton) {
            let joints = Self.jointNames(name).map { skeleton.joint($0) }
            assert(joints.count >= 3)

            self.name = name
            self.joints = joints
        }
    }

    public func finger(_ name: FingerName) -> Finger {
        Finger(name: name, from: self)
    }

    public var fingers: [Finger] {
        FingerName.allCases.map { finger($0) }
    }

    var rootJoint: Joint {
        allJoints.first(where: { $0.parentJoint == nil })!
    }

    var leafJoints: [Joint] {
        let leafJointNames: Set<JointName> = Set([.thumbTip, .indexFingerTip, .middleFingerTip, .ringFingerTip, .littleFingerTip, .forearmArm])
        return allJoints.filter { leafJointNames.contains($0.name) }
    }
}

extension HandSkeleton.Joint: Identifiable {
    public var id: HandSkeleton.JointName {
        name
    }
}

extension HandSkeleton.Joint {
    public var angle: Float {
        let quat = simd_quatf(parentFromJointTransform)
        return quat.angle
    }

    public var relativePosition: simd_float3 {
        anchorFromJointTransform.columns.3.xyz
    }

    public func distance(to other: Self) -> Float {
        let vec = relativePosition - other.relativePosition
        return vec.length
    }
}

extension HandAnchor {
    public typealias FingerName = HandSkeleton.FingerName

    public struct Joint: Identifiable {
        public var id: HandSkeleton.JointName { name }

        public let name: HandSkeleton.JointName
        public let position: simd_float3
        public let angle: Float
        public let isTracked: Bool

        init(handAnchor: HandAnchor, joint: HandSkeleton.Joint) {
            name = joint.name
            position = handAnchor.worldPosition(of: joint)
            angle = joint.angle
            isTracked = joint.isTracked
        }
    }

    public struct Finger {
        public let name: FingerName
        public let tip: Joint
        public let joints: [Joint]
        public let knuckle: Joint

        public var bend: Float {
            guard !joints.isEmpty else { return .zero }
            return joints.reduce(0.0, { $0 + $1.angle }) / Float(joints.count)
        }

        public var angle: Float {
            knuckle.angle
        }

        init(handAnchor: HandAnchor, finger: HandSkeleton.Finger) {
            self.name = finger.name
            var joints = finger.joints.map { joint in
                Joint(handAnchor: handAnchor, joint: joint)
            }

            tip = joints.removeFirst()
            knuckle = joints.removeLast()
            self.joints = joints
        }
    }

    struct Palm {

    }

    public struct Hand {
        public let chirality: HandAnchor.Chirality
        public let fingers: [FingerName:Finger]
        public let originFromAnchorTransform: simd_float4x4
        public let isTracked: Bool

        init?(handAnchor: HandAnchor) {
            guard let skeleton = handAnchor.handSkeleton else {
                return nil
            }

            var fingers: [FingerName:Finger] = [:]

            for finger in skeleton.fingers {
                fingers[finger.name] = Finger(handAnchor: handAnchor, finger: finger)
            }


            chirality = handAnchor.chirality
            self.fingers = fingers
            originFromAnchorTransform = handAnchor.originFromAnchorTransform
            isTracked = handAnchor.isTracked
        }
    }

    public func parse() -> Hand? {
        Hand(handAnchor: self)
    }
}

class HandShapeRecogniger {
    typealias FingerName = HandSkeleton.FingerName
    typealias Hand = HandAnchor.Hand
    typealias Finger = HandAnchor.Finger
    typealias Joint = HandAnchor.Joint

    struct Configuration {
        let bendMinMax: [FingerName:(Float, Float)]
        let defaultBendMinMax: (Float, Float)

        func bendMinMax(of finger: FingerName) -> (Float, Float) {
            if let result = bendMinMax[finger] {
                result
            } else {
                defaultBendMinMax
            }
        }

        static var standard: Self {
            Self(
                bendMinMax: [:],
                defaultBendMinMax: (0.3, 2.0)
            )
        }
    }

    let config: Configuration

    init(config: Configuration = .standard) {
        self.config = config
    }

    enum FingerState: String, Equatable {
        case relaxed, curled, straight, unknown
    }

    struct Result {

    }

    func recognize(hand: Hand) -> Result {
        return Result()
    }

    func state(of finger: Finger, angle: Float, bend: Float) -> FingerState {
        let (min, max) = config.bendMinMax(of: finger.name)

        return if bend < min {
            .straight
        } else if bend > max {
            .curled
        } else {
            .relaxed
        }
    }
}

extension SIMD4 {
    public var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}

extension simd_float3 {
    public var length: Float {
        sqrt(x * x + y * y + z * z)
    }

    public func distance(to other: Self) -> Float {
        (other - self).length
    }
}
