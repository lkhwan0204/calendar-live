# Calendar Pulse (MVP)

Apple 캘린더 일정(EventKit)을 읽어서 다음 일정을 Live Activity(ActivityKit)로 표시하는 iOS 앱 골격입니다.

## 포함된 코드

- App 타깃 코드: `CalendarPulse/App`
- Shared 코드(앱/위젯 공용): `CalendarPulse/Shared`
- Widget Extension 코드: `CalendarPulse/WidgetExtension`

## MVP 기능

- 캘린더/알림 권한 요청
- 24시간 내 다음 일정 조회
- 해당 일정을 Live Activity로 시작/갱신
- 다음 일정 기준 `10분 전` 및 `시작 시점` 로컬 알림 예약
- 앱 active 진입 시 즉시 갱신 + 포그라운드 1분 주기 자동 갱신
- 일정이 없으면 현재 Live Activity 종료

## Xcode 설정 방법

1. Xcode에서 새 iOS App 프로젝트를 생성합니다. (SwiftUI)
2. 프로젝트에 Widget Extension 타깃을 추가합니다.
3. 이 저장소의 파일들을 각 타깃으로 추가합니다.
   - `App` 폴더 파일들: App 타깃
   - `WidgetExtension` 폴더 파일들: Widget Extension 타깃
   - `Shared` 폴더 파일들: App + Widget Extension 둘 다 Target Membership 체크
4. App 타깃 `Signing & Capabilities`에서 `Background Modes`를 추가하고 필요 시 원격 업데이트 옵션을 켭니다.
5. `Info.plist`에 캘린더 권한 문구를 추가합니다.
   - `NSCalendarsUsageDescription`: "일정을 Live Activity로 보여주기 위해 캘린더 접근이 필요합니다."
6. iOS 16.1+ 실제 기기에서 실행합니다.

## 다음 권장 작업

- 여러 캘린더 필터링(회사/개인)
- 앱 재실행 없이 주기 갱신되도록 백그라운드 전략 보강
- 일정 완료 시 자동 종료 정책 고도화
