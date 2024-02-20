//
//  HandModel.swift
//  HandMeasure
//
//  Created by Basuke Suzuki on 2/14/24.
//

import ARKit
import RealityKit
import UIKit

extension Float {
    static public func cm(_ value: Float) -> Float {
        value * 0.01
    }

    static public func mm(_ value: Float) -> Float {
        value * 0.001
    }

    static public func degrees(_ value: Float) -> Float {
        value / 180.0 * .pi
    }

    public var degrees: Float {
        180.0 * self / .pi
    }
}

typealias Joint = HandSkeleton.Joint
typealias JointName = HandSkeleton.JointName

public class HandModel {
    let rootJoint: Joint
    let rootEntity: ModelEntity
    let joints: [JointName:ModelEntity]

    struct JointComponent: Component {
        let joint: Joint
    }

    @MainActor
    convenience init() {
        self.init(skeleton: HandSkeleton.neutralPose)
    }

    @MainActor
    public init(skeleton: HandSkeleton) {
        var joints: [JointName:ModelEntity] = [:]
        var remainingJoints = Set(JointName.allCases)

        func modelEntity(for joint: Joint, color: UIColor, radius: Float = .mm(5)) -> ModelEntity {
            let entity = ModelEntity.jointBall(color: color, radius: radius, opacity: 1.0)
            entity.components.set(JointComponent(joint: joint))

            joints[joint.name] = entity
            remainingJoints.remove(joint.name)

            return entity
        }

        rootJoint = skeleton.rootJoint
        rootEntity = modelEntity(for: rootJoint, color: .white, radius: .cm(1))

        @discardableResult func addModel(for joint: Joint, color: UIColor) -> ModelEntity {
            let parentJoint = joint.parentJoint!

            let entity = modelEntity(for: joint, color: color)
            entity.transform = Transform(matrix: joint.parentFromJointTransform)

            var parentEntity = joints[parentJoint.name]
            if parentEntity == nil {
                parentEntity = addModel(for: parentJoint, color: color)
            }
            parentEntity?.addChild(entity)
            return entity
        }

        let colors: [UIColor] = [.blue, .green, .yellow, .orange, .red, .purple, .systemPink, .brown, .magenta]
        for (joint, color) in zip(skeleton.leafJoints, colors) {
            addModel(for: joint, color:color)
        }

        print("Remaining joints are: \(remainingJoints)")
        self.joints = joints
    }

    public func update(_ skeleton: HandSkeleton, anchor: HandAnchor) {
        for joint in skeleton.allJoints {
            if joint.name == rootJoint.name {
                let matrix = matrix_multiply(anchor.originFromAnchorTransform, joint.anchorFromJointTransform)
                rootEntity.transform = Transform(matrix: matrix)
            } else {
                if let entity = joints[joint.name] {
                    entity.transform = Transform(matrix: joint.parentFromJointTransform)
                }
            }
        }
    }
}


extension ModelEntity {
    /// Creates an invisible sphere that can interact with dropped cubes in the scene.
    static func jointBall(color: UIColor, radius: Float, opacity: Float) -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [UnlitMaterial(color: color)],
            collisionShape: .generateSphere(radius: radius),
            mass: 0.0)

        entity.components.set(PhysicsBodyComponent(mode: .kinematic))
        entity.components.set(OpacityComponent(opacity: opacity))

        return entity
    }
}
