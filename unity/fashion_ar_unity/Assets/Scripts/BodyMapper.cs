using UnityEngine;
using UnityEngine.XR.ARFoundation;

/// <summary>
/// Receives pose landmark data from Flutter (via FlutterBridge) and maps
/// the 33 MediaPipe body landmarks to a Unity Humanoid skeleton.
/// Drives the garment's bones in real-time so the clothing follows
/// the user's body movement frame-by-frame.
/// </summary>
public class BodyMapper : MonoBehaviour
{
    [Header("Target Humanoid")]
    [Tooltip("The Animator component attached to the humanoid garment model")]
    public Animator targetAnimator;

    [Header("Smoothing")]
    [Range(0.1f, 0.95f)]
    public float smoothingFactor = 0.6f;

    [Range(0.05f, 0.5f)]
    public float positionSmoothSpeed = 0.15f;

    // MediaPipe Pose Landmark indices
    private const int NOSE = 0;
    private const int LEFT_SHOULDER = 11;
    private const int RIGHT_SHOULDER = 12;
    private const int LEFT_ELBOW = 13;
    private const int RIGHT_ELBOW = 14;
    private const int LEFT_WRIST = 15;
    private const int RIGHT_WRIST = 16;
    private const int LEFT_HIP = 23;
    private const int RIGHT_HIP = 24;
    private const int LEFT_KNEE = 25;
    private const int RIGHT_KNEE = 26;

    // Smoothed landmark positions (world space)
    private Vector3[] smoothedLandmarks = new Vector3[33];
    private bool hasReceivedData = false;

    // Cached bone transforms from the humanoid avatar
    private Transform hips;
    private Transform spine;
    private Transform chest;
    private Transform leftUpperArm;
    private Transform leftLowerArm;
    private Transform leftHand;
    private Transform rightUpperArm;
    private Transform rightLowerArm;
    private Transform rightHand;
    private Transform leftUpperLeg;
    private Transform leftLowerLeg;
    private Transform rightUpperLeg;
    private Transform rightLowerLeg;

    // Initial rotations (T-pose reference)
    private Quaternion[] initialRotations;

    void Start()
    {
        if (targetAnimator == null)
        {
            targetAnimator = GetComponentInChildren<Animator>();
        }

        CacheBoneTransforms();

        // Store initial T-pose rotations for delta calculation
        if (targetAnimator != null && targetAnimator.isHuman)
        {
            initialRotations = new Quaternion[13];
            initialRotations[0] = hips != null ? hips.localRotation : Quaternion.identity;
            initialRotations[1] = spine != null ? spine.localRotation : Quaternion.identity;
            initialRotations[2] = chest != null ? chest.localRotation : Quaternion.identity;
            initialRotations[3] = leftUpperArm != null ? leftUpperArm.localRotation : Quaternion.identity;
            initialRotations[4] = leftLowerArm != null ? leftLowerArm.localRotation : Quaternion.identity;
            initialRotations[5] = leftHand != null ? leftHand.localRotation : Quaternion.identity;
            initialRotations[6] = rightUpperArm != null ? rightUpperArm.localRotation : Quaternion.identity;
            initialRotations[7] = rightLowerArm != null ? rightLowerArm.localRotation : Quaternion.identity;
            initialRotations[8] = rightHand != null ? rightHand.localRotation : Quaternion.identity;
            initialRotations[9] = leftUpperLeg != null ? leftUpperLeg.localRotation : Quaternion.identity;
            initialRotations[10] = leftLowerLeg != null ? leftLowerLeg.localRotation : Quaternion.identity;
            initialRotations[11] = rightUpperLeg != null ? rightUpperLeg.localRotation : Quaternion.identity;
            initialRotations[12] = rightLowerLeg != null ? rightLowerLeg.localRotation : Quaternion.identity;
        }
    }

    void CacheBoneTransforms()
    {
        if (targetAnimator == null || !targetAnimator.isHuman) return;

        hips = targetAnimator.GetBoneTransform(HumanBodyBones.Hips);
        spine = targetAnimator.GetBoneTransform(HumanBodyBones.Spine);
        chest = targetAnimator.GetBoneTransform(HumanBodyBones.Chest);
        leftUpperArm = targetAnimator.GetBoneTransform(HumanBodyBones.LeftUpperArm);
        leftLowerArm = targetAnimator.GetBoneTransform(HumanBodyBones.LeftLowerArm);
        leftHand = targetAnimator.GetBoneTransform(HumanBodyBones.LeftHand);
        rightUpperArm = targetAnimator.GetBoneTransform(HumanBodyBones.RightUpperArm);
        rightLowerArm = targetAnimator.GetBoneTransform(HumanBodyBones.RightLowerArm);
        rightHand = targetAnimator.GetBoneTransform(HumanBodyBones.RightHand);
        leftUpperLeg = targetAnimator.GetBoneTransform(HumanBodyBones.LeftUpperLeg);
        leftLowerLeg = targetAnimator.GetBoneTransform(HumanBodyBones.LeftLowerLeg);
        rightUpperLeg = targetAnimator.GetBoneTransform(HumanBodyBones.RightUpperLeg);
        rightLowerLeg = targetAnimator.GetBoneTransform(HumanBodyBones.RightLowerLeg);
    }

    /// <summary>
    /// Called by FlutterBridge when new pose data arrives from Flutter.
    /// Expects a JSON string with 33 landmarks, each having x,y,z,visibility.
    /// </summary>
    public void OnPoseDataReceived(string jsonData)
    {
        try
        {
            PoseData poseData = JsonUtility.FromJson<PoseData>(jsonData);
            if (poseData == null || poseData.landmarks == null || poseData.landmarks.Length < 33) return;

            hasReceivedData = true;

            for (int i = 0; i < 33 && i < poseData.landmarks.Length; i++)
            {
                Vector3 raw = new Vector3(
                    poseData.landmarks[i].x,
                    -poseData.landmarks[i].y, // Flip Y for Unity coordinate system
                    poseData.landmarks[i].z
                );

                // Exponential moving average smoothing
                smoothedLandmarks[i] = Vector3.Lerp(smoothedLandmarks[i], raw, smoothingFactor);
            }
        }
        catch (System.Exception e)
        {
            Debug.LogWarning($"BodyMapper: Failed to parse pose data: {e.Message}");
        }
    }

    void LateUpdate()
    {
        if (!hasReceivedData || targetAnimator == null || !targetAnimator.isHuman) return;

        ApplyPoseToSkeleton();
    }

    void ApplyPoseToSkeleton()
    {
        // — Hip position & rotation (root motion) —
        if (hips != null)
        {
            Vector3 hipCenter = (smoothedLandmarks[LEFT_HIP] + smoothedLandmarks[RIGHT_HIP]) * 0.5f;
            hips.position = Vector3.Lerp(hips.position, hipCenter, positionSmoothSpeed);

            Vector3 hipRight = smoothedLandmarks[RIGHT_HIP] - smoothedLandmarks[LEFT_HIP];
            Vector3 hipForward = Vector3.Cross(hipRight, Vector3.up).normalized;
            if (hipForward.sqrMagnitude > 0.001f)
            {
                Quaternion targetRot = Quaternion.LookRotation(hipForward, Vector3.up);
                hips.rotation = Quaternion.Slerp(hips.rotation, targetRot, smoothingFactor);
            }
        }

        // — Spine / Chest rotation —
        if (spine != null)
        {
            Vector3 shoulderCenter = (smoothedLandmarks[LEFT_SHOULDER] + smoothedLandmarks[RIGHT_SHOULDER]) * 0.5f;
            Vector3 hipCenter = (smoothedLandmarks[LEFT_HIP] + smoothedLandmarks[RIGHT_HIP]) * 0.5f;
            Vector3 spineDir = (shoulderCenter - hipCenter).normalized;
            if (spineDir.sqrMagnitude > 0.001f)
            {
                Quaternion spineTarget = Quaternion.FromToRotation(Vector3.up, spineDir);
                spine.rotation = Quaternion.Slerp(spine.rotation, spineTarget, smoothingFactor);
            }
        }

        // — Left arm —
        ApplyLimbRotation(leftUpperArm, LEFT_SHOULDER, LEFT_ELBOW);
        ApplyLimbRotation(leftLowerArm, LEFT_ELBOW, LEFT_WRIST);

        // — Right arm —
        ApplyLimbRotation(rightUpperArm, RIGHT_SHOULDER, RIGHT_ELBOW);
        ApplyLimbRotation(rightLowerArm, RIGHT_ELBOW, RIGHT_WRIST);

        // — Left leg —
        ApplyLimbRotation(leftUpperLeg, LEFT_HIP, LEFT_KNEE);

        // — Right leg —
        ApplyLimbRotation(rightUpperLeg, RIGHT_HIP, RIGHT_KNEE);
    }

    void ApplyLimbRotation(Transform bone, int fromIdx, int toIdx)
    {
        if (bone == null) return;

        Vector3 direction = (smoothedLandmarks[toIdx] - smoothedLandmarks[fromIdx]).normalized;
        if (direction.sqrMagnitude < 0.001f) return;

        Quaternion targetRotation = Quaternion.LookRotation(direction);
        bone.rotation = Quaternion.Slerp(bone.rotation, targetRotation, smoothingFactor);
    }

    // — JSON Data Structures —
    [System.Serializable]
    public class PoseData
    {
        public PoseLandmark[] landmarks;
        public long timestamp;
    }

    [System.Serializable]
    public class PoseLandmark
    {
        public float x;
        public float y;
        public float z;
        public float visibility;
    }
}
