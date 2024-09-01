using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BlittingFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        private ProfilingSampler _profilingSampler;
        private RTHandle rtTemp;
        private BlittingSettings _settings;

        public CustomRenderPass(BlittingSettings _settings)
        {
            this._settings = _settings;
            _profilingSampler = new ProfilingSampler("Blitting");
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureInput(ScriptableRenderPassInput.Normal);
            var colorDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            colorDescriptor.depthBufferBits = 0;
            RenderingUtils.ReAllocateIfNeeded(ref rtTemp, colorDescriptor, name: "tempTex");
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(name: "BlittingPass");
            RTHandle rtCamera = renderingData.cameraData.renderer.cameraColorTargetHandle;

            using (new ProfilingScope(cmd, _profilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                Blit(cmd, rtCamera, rtTemp, _settings.material);
                Blit(cmd, rtTemp, rtCamera);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd) {}

        public void ReleaseTargets()
        {
            rtTemp?.Release();
        }
    }

    private CustomRenderPass m_ScriptablePass;
    public BlittingSettings _settings;

    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass(this._settings);
        m_ScriptablePass.renderPassEvent = (_settings.rpEvent);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (renderingData.cameraData.isSceneViewCamera && !_settings.inScene)
            return;

        if (renderingData.cameraData.isPreviewCamera)
            return;

        renderer.EnqueuePass(m_ScriptablePass);
    }

    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass.ReleaseTargets();
    }
}