# Setup Checklist

## 최소 iOS 버전

- App target deployment: iOS 16.1 이상
- Widget Extension deployment: iOS 16.1 이상

## Info.plist (App)

- `NSCalendarsUsageDescription`

## Capabilities

- App: `Background Modes` (필요 기능에 따라 선택)
- App + Widget: Live Activities 사용 가능한 타깃 설정 확인

## Target Membership

- `CalendarActivityAttributes.swift`: App + Widget 둘 다 포함
- `CalendarEvent.swift`: App만 포함해도 되지만 공용으로 유지 가능

## 테스트

- 시뮬레이터보다 실제 기기(iPhone, iOS 16.1+) 권장
- Apple Calendar에 가까운 시간의 테스트 일정 생성 후 앱 실행
- "캘린더/알림 권한 요청" 버튼으로 두 권한 허용
- "다음 일정 새로고침" 버튼으로 Live Activity 및 10분 전/시작 알림 예약 확인
