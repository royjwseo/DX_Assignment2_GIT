# DirectX 12 3D Game Programming 2 — Assignment #02

> **2023년 2학기 | 3D게임프로그래밍2 과제 #02**  
> 학번: 2019184016 | 이름: 서정원

---

## 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [기술 스택](#기술-스택)
3. [조작법](#조작법)
4. [구현 기능 상세](#구현-기능-상세)
   - [스카이박스 (낮/밤 전환)](#1-스카이박스--낮밤-전환)
   - [테셀레이션 지형](#2-테셀레이션-지형)
   - [환경 매핑 (거울 구 / 거울 방)](#3-환경-매핑--거울-구--거울-방)
   - [파티클 시스템](#4-파티클-시스템)
   - [스킨 메시 애니메이션](#5-스킨-메시-애니메이션)
5. [렌더링 파이프라인 구조](#렌더링-파이프라인-구조)
6. [실행 결과](#실행-결과)

---

## 프로젝트 개요

Terrain만 구성된 기본 DirectX 12 프로젝트에서 출발하여, 다음 목표를 단계적으로 구현한 과제입니다.

| 구분 | 내용 |
|------|------|
| **필수 구현** | 테셀레이션 지형, 환경 매핑 구, 거울 방 |
| **추가 구현** | 스킨 메시 + 애니메이션 Set 6종, 파티클(기하 셰이더), 스카이박스 밤낮 전환, 지형 동적 알파블렌딩, 테셀레이션 높이 3단 보간 |

단순한 게임 기능 구현보다는 **멀티패스 렌더링 플로우**(PreRender → OnPrepareRender → Render → PostRender)와 **DirectX 12 셰이더 파이프라인 전 단계** 활용에 초점을 두었습니다.

---

## 기술 스택

- **API**: DirectX 12
- **언어**: C++, HLSL
- **셰이더 단계 활용**: Vertex / Hull / Tessellator / Domain / Geometry / Pixel Shader
- **텍스쳐 로더**: DDSTextureLoader12, WICTextureLoader12
- **애니메이션 소스**: Unity 엔진에서 Binary 파일로 추출

---

## 조작법

| 키 | 동작 |
|----|------|
| `↑ ↓ ← →` | 전후좌우 이동 (이동 애니메이션 연동) |
| `Shift + ↑` | 앞으로 달리기 |
| `Ctrl` (꾹) | 공격 모션 1 |
| `Space` (꾹) | 공격 모션 2 |
| `W` | 와이어프레임 토글 (테셀레이션 확인용) |

---

## 구현 기능 상세

### 1. 스카이박스 — 낮/밤 전환

**목표**: 스카이박스 텍스쳐를 시간에 따라 전환하여 낮과 밤을 표현, 환경 매핑 구에도 실시간 반사 적용.

**핵심 문제**: 텍스쳐 자체를 픽셀 셰이더 내에서 전환하면 PreRender(1-pass)에서 미리 렌더링되는 환경 매핑 구에 변경 사항이 반영되지 않음.

**해결 방법**:
- 스카이박스 생성 시 큐브맵 텍스쳐 16개를 한꺼번에 로드 (`CTexture(16, RESOURCE_TEXTURE_CUBE, 0, 1)`)
- 각 텍스쳐는 별도의 SRV 핸들을 보유
- `stdafx.h`에 `extern int g_SkyboxTextureIndex` 전역 변수 선언
- `GameFramework`의 `FrameAdvance()`에서 시간에 따라 인덱스를 갱신
- `Object.cpp`에서 `SetGraphicsRootDescriptorTable` 호출 시 해당 인덱스의 핸들을 Set → PreRender에서도 동일하게 반영

**추가**: Directional Light의 밝기를 스카이박스 텍스쳐 전환 타이밍에 맞게 조절하여 밤낮 분위기를 실감 나게 표현.

| 낮 | 밤 |
|----|----|
| ![낮](https://github.com/user-attachments/assets/16108cab-867d-4936-bb9d-eeb31b050883) | ![밤](https://github.com/user-attachments/assets/59b7cbe2-e2c4-4f05-9378-a31cd0d524ad) |

---

### 2. 테셀레이션 지형

**목표**: 하이트맵 기반 지형에 GPU 테셀레이션을 적용하여 카메라 거리에 따른 동적 LOD 구현.

**파이프라인 변경**:
- 루트 시그니처 플래그에서 HS/DS 비활성 플래그 제거
- `HullShader`, `DomainShader`를 파이프라인에 추가

**동작 원리**:

```
VS (정점 전달)
  → HS (패치 단위로 카메라 거리 기반 TessFactor / InsideTessFactor 결정, Quad 도메인)
    → Tessellator (제어점 추가)
      → DS (SV_DomainLocation + Bezier 보간으로 월드 좌표 재계산)
        → PS
```

**추가 구현**:
- **높이 3중 보간**: 패치 단위 테셀레이션으로 발생하는 높이 오차를 Trilinear 보간 공식으로 보정
- **동적 알파블렌딩**: 카메라와의 거리를 원형으로 계산하여 알파값을 보간 → 투시 레이더 효과 실험
  - 발견된 한계: 단일 오브젝트 내 정점 렌더링 순서가 고정되어 있어 특정 방향에서만 투시 효과가 올바르게 보임

![테셀레이션](https://github.com/user-attachments/assets/82deee72-34a5-4c38-bee6-8db2f7bf9be2)

---

### 3. 환경 매핑 — 거울 구 / 거울 방

#### 거울 구 (Dynamic Cube Mapping)

| 단계 | 내용 |
|------|------|
| 초기화 | 구 오브젝트 생성 시 카메라 6개(+X/−X/+Y/−Y/+Z/−Z) 생성, RTV 6개 + DSV + 큐브 텍스쳐 미리 생성 |
| PreRender (1-pass) | 6개 카메라로 각 방향 씬을 렌더타겟에 렌더링 후 큐브 텍스쳐에 저장 |
| Render (2-pass) | 저장된 큐브 텍스쳐를 구 메시에 매핑 → 동적 반사 표현 |

스카이박스 SRV 핸들 교체 방식 덕분에 밤낮 변화가 구의 반사에도 실시간으로 반영됨.

#### 거울 방 (TextureRect Mirror)

- Unity에서 벽/기둥 메시를 직접 조합하여 건물 모델 제작 후 Binary 추출
- 각 벽면마다 카메라를 배치, 해당 방향 씬을 Texture2D에 렌더링 후 벽면에 매핑
- UV 좌표 오류(은면/양면 판정 문제) 수작업 수정
- 환경 매핑 구와 충돌 시 거울 방으로 씬 전환 (`SceneMode` enum으로 관리)

| 거울 구 (낮) | 거울 구 (밤) |
|---|---|
| ![낮구](https://github.com/user-attachments/assets/063cfdf4-915f-428e-91d1-3357cc8d3e6d) | ![밤구](https://github.com/user-attachments/assets/ce918109-fd8f-4ec1-accc-abcae016c444) |

![거울방](https://github.com/user-attachments/assets/5754e89d-268c-4759-8dd6-23894bebba33)

---

### 4. 파티클 시스템

**목표**: Geometry Shader를 활용하여 정점 1개로부터 빌보드 쿼드를 생성하는 파티클 구현.

**버퍼 구조**:

| 버퍼 | 역할 |
|------|------|
| 초기 정점 버퍼 | 파티클 시스템 시작 상태의 정점 정보 저장 |
| 스트림 출력 버퍼 | 매 프레임 위치·속도 등 시뮬레이션 결과를 GPU에서 직접 기록 |
| 렌더링 버퍼 | 스트림 출력 버퍼 → 렌더링 버퍼로 복사 후 Draw |

업데이트와 렌더링을 분리하여 병렬 처리 → 성능 향상.

**렌더링 흐름**:
- `PreRender`: 메시 및 정점 버퍼 초기 정의
- `Render`: 스트림 출력으로 파티클 업데이트 및 빌보드 렌더
- `PostRender`: 스트림 출력 버퍼 닫기

![파티클](https://github.com/user-attachments/assets/0c26e3ac-765b-4086-8b7a-f644dde235aa)

---

### 5. 스킨 메시 애니메이션

**목표**: Unity에서 추출한 스킨 메시 모델에 애니메이션 Set 6종을 적용.

**Unity 추출 과정**:
1. 모델 Rig 설정: 뼈 가중치 4개, Humanoid, Read/Write 활성화
2. AnimationController 생성 및 애니메이션 Set 배정
3. Binary 파일로 추출

**애니메이션 컨트롤러 구조**:
- `CAnimationController`: 트랙 배열 관리, AnimationSet 보관, 스킨 메시 배열 및 뼈 공간 변환 행렬 버퍼 내부 관리
- `SetTrackAnimationSet()`: 인덱스별 AnimationSet 등록
- `AdvanceTime()`: 매 프레임 시간 추적 → `GetSrt()`로 키프레임 간 보간 → 뼈대 변환 행렬 누적

**Vertex Shader (스킨 애니메이션)**:
```hlsl
// 상수 버퍼로 전달된 BoneTransform × BoneOffset을 가중치와 함께 곱하여
// 각 본 계층구조의 오프셋 변환행렬로 본 공간으로 이동 후 최종 월드 좌표 계산
output.pos = BoneOffset[boneIndex] × BoneTransform[boneIndex] × weight
```

**애니메이션 종류 (6종)**:

| 인덱스 | 애니메이션 | 트리거 |
|--------|------------|--------|
| 0 | IDLE | 기본 상태 상시 |
| 1 | 앞으로 이동 | `↑` |
| 2 | 옆으로 이동 | `← →` |
| 3 | 뒤로 이동 | `↓` |
| 4 | 달리기 | `Shift + ↑` |
| 5 | 공격 1 | `Ctrl` |
| 6 | 공격 2 | `Space` |

![애니메이션](https://github.com/user-attachments/assets/09fe1134-2d41-40ff-8191-67ca7356f86f)

---

## 렌더링 파이프라인 구조

```
GameFramework::FrameAdvance()
│
├── Scene::OnPreRender()          ← 1-pass (환경 매핑 PreRender)
│     ├── 환경 매핑 구 : 6방향 카메라로 씬 렌더 → CubeMap 저장
│     └── 거울 방 : 각 벽면 카메라로 씬 렌더 → Texture2D 저장
│
├── Scene::PrepareRender()        ← 공통 셰이더 변수 업데이트
│
├── Particle PreRender            ← 파티클 스트림 출력 시작
│
├── Scene::Render()               ← 2-pass (최종 씬 렌더링)
│     ├── SkyBox
│     ├── Terrain (테셀레이션)
│     ├── 환경 매핑 구 (CubeMap 매핑)
│     ├── 거울 방 (Texture2D 매핑)
│     ├── Player (스킨 메시 + 애니메이션)
│     └── Particle Render
│
└── Particle PostRender           ← 스트림 출력 버퍼 닫기
```

---

## 실행 결과

### 전체 씬 (위에서 조망)
![씬 전체](https://github.com/user-attachments/assets/7687570b-95ab-4b93-b511-9f3db2c1fc0c)

### 플레이어 애니메이션 — 달리기
![달리기](https://github.com/user-attachments/assets/466a71b0-6cd8-4f55-b0d7-4987e57b5d90)

### 플레이어 애니메이션 — 공격
![공격](https://github.com/user-attachments/assets/09fe1134-2d41-40ff-8191-67ca7356f86f)

### 지형 알파블렌딩 (카메라 거리 기반)
![알파블렌딩](https://github.com/user-attachments/assets/37fd7262-2d13-4f3c-95ad-afe3490c8500)

### 거울 방 내부
![거울방](https://github.com/user-attachments/assets/d1dd9fea-1ba4-4344-8d9b-41bc98019455)

---

*개발 기간: 2023년 2학기*
