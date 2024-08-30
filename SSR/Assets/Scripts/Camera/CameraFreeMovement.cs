using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraFreeMovement : MonoBehaviour
{
    [SerializeField] private float movementSpeed = 1f;
    [SerializeField] private float shiftSpeedMultiplier = 2f;
    [SerializeField] private float mouseSensitivity = 1f;

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void Update()
    {
        Vector4 inputs = new Vector4(
            Input.GetAxisRaw("Horizontal"),
            Input.GetAxisRaw("Vertical"),
            Input.GetAxisRaw("Mouse X"),
            Input.GetAxisRaw("Mouse Y"));

        float spaceBar = 0f;
        if (Input.GetKey(KeyCode.Space))
            spaceBar = 1f;
        if (Input.GetKey(KeyCode.LeftControl))
            spaceBar = -1f;

        float speedMultiplier = (Input.GetKey(KeyCode.LeftShift)) ? shiftSpeedMultiplier : 1f;

        transform.position += transform.right * inputs.x * Time.deltaTime * movementSpeed * speedMultiplier +
                              transform.forward * inputs.y * Time.deltaTime * movementSpeed * speedMultiplier +
                              Vector3.up * spaceBar * Time.deltaTime * movementSpeed * speedMultiplier;

        transform.rotation = Quaternion.Euler(Vector3.up * inputs.z * mouseSensitivity + transform.right * -inputs.w * mouseSensitivity) * transform.rotation;
    }
}
