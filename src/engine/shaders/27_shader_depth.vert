#version 450

// layout(set = 0, binding = 0) uniform UniformBufferObject {
//     mat4 model;
//     mat4 view;
//     mat4 proj;
// } ubo;

// ----------------------------------------------

struct SceneData {
    mat4 model;
    mat4 view;
    mat4 proj;
    mat4 reserved_0;
};

// std140 enforces cpp memory layout
layout(std140, set = 1, binding = 0) readonly buffer SceneStorage {
    SceneData data[];
} scene_storage;

layout(push_constant) uniform PushConstants {
    uint object_idx;
} push_constants;




layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inColor;
layout(location = 2) in vec2 inTexCoord;

layout(location = 0) out vec3 fragColor;
layout(location = 1) out vec2 fragTexCoord;

void main() {
    // gl_Position = ubo.proj * ubo.view * ubo.model * vec4(inPosition, 1.0);

    SceneData scene_data = scene_storage.data[push_constants.object_idx];
    gl_Position = scene_data.proj * scene_data.view * scene_data.model * vec4(inPosition, 1.0);

    fragColor = inColor;
    fragTexCoord = inTexCoord;
}
