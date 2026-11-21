package com.ribhlab.fingerverse;

import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.Matrix;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.ShortBuffer;
import java.util.Random;
import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

/** Pure GLES2 procedural 3D world. No pre-rendered planet images or external engine. */
public final class WorldRenderer implements GLSurfaceView.Renderer {
    private static final String PLANET_VS =
            "attribute vec3 aPos;\n" +
            "uniform mat4 uMVP; uniform mat4 uModel;\n" +
            "varying vec3 vN; varying vec3 vP;\n" +
            "void main(){ vP = aPos; vN = normalize((uModel*vec4(aPos,0.0)).xyz);" +
            "gl_Position = uMVP*vec4(aPos,1.0); }";
    private static final String PLANET_FS =
            "precision mediump float;\n" +
            "varying vec3 vN; varying vec3 vP;\n" +
            "uniform float uTime; uniform float uSeed; uniform float uType; uniform float uAwake;\n" +
            "float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}\n" +
            "float noise3(vec3 p){vec3 i=floor(p);vec3 f=fract(p); f=f*f*(3.0-2.0*f);" +
            "return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x)," +
            "mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y)," +
            "mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x)," +
            "mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}\n" +
            "void main(){\n" +
            "vec3 n=normalize(vP); float m=noise3(n*4.3+uSeed);" +
            "m=m*0.67+noise3(n*11.1+uSeed*0.2)*0.33;" +
            "float land=smoothstep(0.46,0.55,m);" +
            "float temp=0.5+0.5*sin(uSeed*1.8);" +
            "vec3 sea=mix(vec3(0.025,0.10,0.31),vec3(0.05,0.37,0.47),temp);" +
            "vec3 terrain=mix(vec3(0.03,0.32,0.26),vec3(0.44,0.22,0.68),temp);" +
            "vec3 rock=vec3(0.36,0.24,0.57);" +
            "vec3 color=mix(sea,terrain,land);" +
            "color=mix(color,vec3(0.78,0.93,1.0),smoothstep(0.79,0.94,abs(n.y)) * land);" +
            "if(uType>0.5){ color=mix(rock,vec3(0.12,0.75,0.91),m*0.9);" +
            "color+=vec3(0.12,0.2,0.36)*pow(sin(n.x*22.0+uSeed+n.y*13.0)*0.5+0.5,12.0);}" +
            "float light=max(dot(normalize(vN),normalize(vec3(-0.44,0.74,0.9))),0.0);" +
            "float rim=pow(1.0-max(dot(normalize(vN),vec3(0.0,0.0,1.0)),0.0),3.0);" +
            "float pulse=0.8+0.2*sin(uTime*1.8+uSeed);" +
            "color*=0.22+0.81*light;" +
            "color+=vec3(0.03,0.48,0.93)*rim*pulse*(0.4+uAwake*1.15);" +
            "color=mix(color*0.21+rim*vec3(0.03,0.19,0.3),color,uAwake);" +
            "gl_FragColor=vec4(color,1.0); }";

    private static final String STAR_VS =
            "attribute vec3 aPos; varying float vIntensity;\n" +
            "void main(){gl_Position=vec4(aPos.xy,0.9,1.0);" +
            "vIntensity=aPos.z; gl_PointSize=1.0+aPos.z*3.1;}";
    private static final String STAR_FS =
            "precision mediump float; varying float vIntensity;\n" +
            "void main(){float d=length(gl_PointCoord-vec2(0.5));" +
            "float alpha=(1.0-smoothstep(0.0,0.5,d))*vIntensity;" +
            "gl_FragColor=vec4(0.38+0.6*vIntensity,0.66+0.3*vIntensity,1.0,alpha); }";

    private volatile float gravX = 0f;
    private volatile float gravY = 0f;
    private volatile int worldIndex = 0;
    private int drawnIndex = 0;
    private float live = 0f;
    private long startTime;
    private int planetProgram, starProgram;
    private FloatBuffer mesh, stars;
    private ShortBuffer triangles;
    private int indexCount;
    private final float[] proj = new float[16];
    private final float[] view = new float[16];
    private final float[] vp = new float[16];
    private final float[] model = new float[16];
    private final float[] mvp = new float[16];

    public void setGravity(float x, float y) {
        gravX = gravX*0.85f + Math.max(-9.8f,Math.min(9.8f,x))*0.15f;
        gravY = gravY*0.85f + Math.max(-9.8f,Math.min(9.8f,y))*0.15f;
    }
    public void awaken(int version) { worldIndex = version; }

    @Override public void onSurfaceCreated(GL10 gl, EGLConfig config) {
        GLES20.glClearColor(0.012f,0.017f,0.066f,1f);
        GLES20.glEnable(GLES20.GL_DEPTH_TEST);
        planetProgram = program(PLANET_VS, PLANET_FS);
        starProgram = program(STAR_VS, STAR_FS);
        buildSphere(32, 54);
        buildStars(280);
        startTime = System.nanoTime();
    }

    @Override public void onSurfaceChanged(GL10 gl, int width, int height) {
        GLES20.glViewport(0,0,width,height);
        Matrix.perspectiveM(proj,0,43.0f,(float)width/Math.max(1,height),0.1f,100f);
        Matrix.setLookAtM(view,0,0f,0.08f,8.4f,0f,0f,0f,0f,1f,0f);
        Matrix.multiplyMM(vp,0,proj,0,view,0);
    }

    @Override public void onDrawFrame(GL10 gl) {
        float t = (System.nanoTime()-startTime)*0.000000001f;
        if (drawnIndex != worldIndex) drawnIndex = worldIndex;
        float target=drawnIndex>0?1f:0f;
        live += (target-live)*0.013f;

        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT|GLES20.GL_DEPTH_BUFFER_BIT);
        drawStars();
        GLES20.glEnable(GLES20.GL_DEPTH_TEST);
        GLES20.glDisable(GLES20.GL_BLEND);

        float angle=t*9.0f + gravX*4.5f;
        float tilt=gravY*2.7f;
        float size=1.30f + live*0.25f;

        Matrix.setIdentityM(model,0);
        Matrix.translateM(model,0,0f,0.05f,0f);
        Matrix.rotateM(model,0,tilt+12f,1f,0f,0f);
        Matrix.rotateM(model,0,angle,0f,1f,0f);
        Matrix.scaleM(model,0,size,size,size);
        drawSphere(t, model, 0f, live);

        if (live>0.03f) {
            int count=12;
            for (int i=0;i<count;i++) {
                float phase=(float)(i*2.39996323 + t*(0.20+(i%4)*0.055f));
                float radius=1.95f+(i%3)*0.37f;
                float x=(float)Math.cos(phase)*radius + gravX*0.035f;
                float y=(float)Math.sin(phase)*(0.77f+(i%4)*0.19f) + gravY*0.05f;
                float z=(float)Math.sin(phase*0.71+i)*0.85f;
                float rockSize=(0.11f + (i%4)*0.04f)*live;
                Matrix.setIdentityM(model,0);
                Matrix.translateM(model,0,x,y,z);
                Matrix.rotateM(model,0,t*24f + i*67f,0.5f,0.9f,0.2f);
                Matrix.scaleM(model,0,rockSize,rockSize*(0.8f+i%2),rockSize);
                drawSphere(t,model,1f,live);
            }
        }
    }

    private void drawSphere(float time, float[] modelMatrix, float type, float awake) {
        GLES20.glUseProgram(planetProgram);
        Matrix.multiplyMM(mvp,0,vp,0,modelMatrix,0);
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(planetProgram,"uMVP"),1,false,mvp,0);
        GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(planetProgram,"uModel"),1,false,modelMatrix,0);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(planetProgram,"uTime"),time);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(planetProgram,"uSeed"),1.35f+drawnIndex*2.713f);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(planetProgram,"uType"),type);
        GLES20.glUniform1f(GLES20.glGetUniformLocation(planetProgram,"uAwake"),awake);
        int pos=GLES20.glGetAttribLocation(planetProgram,"aPos");
        GLES20.glEnableVertexAttribArray(pos);
        mesh.position(0);
        GLES20.glVertexAttribPointer(pos,3,GLES20.GL_FLOAT,false,12,mesh);
        triangles.position(0);
        GLES20.glDrawElements(GLES20.GL_TRIANGLES,indexCount,GLES20.GL_UNSIGNED_SHORT,triangles);
        GLES20.glDisableVertexAttribArray(pos);
    }

    private void drawStars() {
        GLES20.glDisable(GLES20.GL_DEPTH_TEST);
        GLES20.glEnable(GLES20.GL_BLEND);
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA,GLES20.GL_ONE);
        GLES20.glUseProgram(starProgram);
        int pos=GLES20.glGetAttribLocation(starProgram,"aPos");
        GLES20.glEnableVertexAttribArray(pos);
        stars.position(0);
        GLES20.glVertexAttribPointer(pos,3,GLES20.GL_FLOAT,false,12,stars);
        GLES20.glDrawArrays(GLES20.GL_POINTS,0,stars.capacity()/3);
        GLES20.glDisableVertexAttribArray(pos);
        GLES20.glDisable(GLES20.GL_BLEND);
    }

    private void buildSphere(int stacks, int slices) {
        float[] verts = new float[(stacks+1)*(slices+1)*3];
        short[] inds = new short[stacks*slices*6];
        int v=0, k=0;
        for(int lat=0;lat<=stacks;lat++) {
            double phi=Math.PI*lat/stacks;
            for(int lon=0;lon<=slices;lon++) {
                double theta=2*Math.PI*lon/slices;
                verts[v++]=(float)(Math.sin(phi)*Math.cos(theta));
                verts[v++]=(float)Math.cos(phi);
                verts[v++]=(float)(Math.sin(phi)*Math.sin(theta));
            }
        }
        for(int lat=0;lat<stacks;lat++) {
            for(int lon=0;lon<slices;lon++) {
                int p=lat*(slices+1)+lon;
                inds[k++]=(short)p; inds[k++]=(short)(p+slices+1); inds[k++]=(short)(p+1);
                inds[k++]=(short)(p+1); inds[k++]=(short)(p+slices+1); inds[k++]=(short)(p+slices+2);
            }
        }
        mesh=ByteBuffer.allocateDirect(verts.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();
        mesh.put(verts).position(0);
        triangles=ByteBuffer.allocateDirect(inds.length*2).order(ByteOrder.nativeOrder()).asShortBuffer();
        triangles.put(inds).position(0);
        indexCount=inds.length;
    }

    private void buildStars(int count) {
        Random rand=new Random(1942L);
        float[] data=new float[count*3];
        for(int i=0;i<count;i++){
            data[i*3]=rand.nextFloat()*2f-1f;
            data[i*3+1]=rand.nextFloat()*2f-1f;
            data[i*3+2]=0.3f+rand.nextFloat()*0.7f;
        }
        stars=ByteBuffer.allocateDirect(data.length*4).order(ByteOrder.nativeOrder()).asFloatBuffer();
        stars.put(data).position(0);
    }

    private int shader(int type,String text) {
        int s=GLES20.glCreateShader(type);
        GLES20.glShaderSource(s,text);
        GLES20.glCompileShader(s);
        int[] ok=new int[1];
        GLES20.glGetShaderiv(s,GLES20.GL_COMPILE_STATUS,ok,0);
        if(ok[0]==0) throw new IllegalStateException(GLES20.glGetShaderInfoLog(s));
        return s;
    }
    private int program(String vertex,String fragment) {
        int v=shader(GLES20.GL_VERTEX_SHADER,vertex);
        int f=shader(GLES20.GL_FRAGMENT_SHADER,fragment);
        int p=GLES20.glCreateProgram();
        GLES20.glAttachShader(p,v);
        GLES20.glAttachShader(p,f);
        GLES20.glLinkProgram(p);
        int[] ok=new int[1];
        GLES20.glGetProgramiv(p,GLES20.GL_LINK_STATUS,ok,0);
        if(ok[0]==0) throw new IllegalStateException(GLES20.glGetProgramInfoLog(p));
        GLES20.glDeleteShader(v); GLES20.glDeleteShader(f);
        return p;
    }
}