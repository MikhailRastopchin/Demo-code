// ignore_for_file: use_build_context_synchronously

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:helpers/auto_route.gr.dart';
import 'package:presentation/main/chats/bloc/dialogs_bloc.dart';
import 'package:presentation/main/chats/widgets/list_dialogs.dart';
import 'package:presentation/main/profile/bloc/profile_bloc.dart';
import 'package:presentation/main/profile/bloc/profile_type_handling_bloc.dart';
import 'package:presentation/main/tab_navigation_screen.dart';
import 'package:presentation/widgets/custom_appbar.dart';
import 'package:presentation/widgets/flushbar.dart';
import 'package:presentation/widgets/ui_kit/ui_kit.dart';
import 'package:resources/colors.dart';
import 'package:resources/images.dart';

@RoutePage()
class DialogsUserScreen extends StatefulWidget {
  const DialogsUserScreen({super.key});

  @override
  State<DialogsUserScreen> createState() => _DialogsUserScreenState();
}

class _DialogsUserScreenState extends State<DialogsUserScreen> {
  late TextEditingController _controller;
  bool showCross = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      if (_controller.text.isNotEmpty) {
        visibleCross(true);
      } else {
        visibleCross(false);
      }
    });
  }

  void visibleCross(val) {
    if (mounted) {
      setState(() {
        showCross = val;
      });
    }
  }

  Future<void> _showSellerNotification(
    BuildContext context,
    TabChangeNotifier tabChangeNotifier,
  ) async {
    if (tabChangeNotifier.currentTabIndex == 3) {
      final isSellerMode = context
          .read<ProfileTypeHandlingBloc>()
          .state
          .isSellerMode;
      final profileBloc = context.read<ProfileBloc>();
      final profile = profileBloc.state.mainProfile;
      final emptyProfile = profile?.email == null;
      final accounts = profileBloc.state.accounts;
      final account = accounts!.firstWhere(
        (account) => account.id == profile!.userId,
      );
      if (isSellerMode) {
        if (account.showFirstSellerPush && emptyProfile) {
          await Future.delayed(const Duration(seconds: 2));
          await CustomFlushBar.showFlushBarWithButton(
            title: 'Заполните данные Продавца',
            subtitle:
                'Добавляйте товары и совершайте сделки внутри приложения.',
            context: context,
          );
          context.read<ProfileBloc>().add(
            const ProfileEvent.firstSellerPushWasShown(),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSeller = context.read<ProfileTypeHandlingBloc>().state.isSellerMode;
    return Consumer<TabChangeNotifier>(
      builder: (context, tabChangeNotifier, child) {
        if (tabChangeNotifier.currentTabIndex == 3) {
          _showSellerNotification(context, tabChangeNotifier);
        }
        return child!;
      },
      child: BlocBuilder<DialogsBloc, DialogsState>(
        builder: (context, state) {
          return BlocConsumer<
            ProfileTypeHandlingBloc,
            ProfileTypeHandlingState
          >(
            listener: (context, profileState) {
              if (profileState.isFetchingProfileType) {
                setState(() => _controller.clear());
                final bloc = context.read<DialogsBloc>();
                bloc.add(DialogsEvent.fetch(ownProfileId: state.ownProfileId!));
              }
            },
            builder: (context, profileState) {
              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Scaffold(
                  backgroundColor: Colors.white,
                  appBar: CustomAppBar(
                    leadingWidget: Center(
                      child: AppIcons.message(size: 24, color: Colors.white),
                    ),
                    title: 'Сообщения',
                    hasNotifIcon: true,
                    hasShopIcon: !profileState.isSellerMode,
                  ),
                  body: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 38,
                          width: MediaQuery.of(context).size.width,
                          child: TextField(
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16.h,
                              fontFamily: "GilroyRegular",
                              fontWeight: FontWeight.w400,
                            ),
                            onSubmitted: (v) {
                              final bloc = context.read<DialogsBloc>();
                              bloc.add(
                                DialogsEvent.fetch(
                                  ownProfileId: state.ownProfileId!,
                                  search: v,
                                ),
                              );
                            },
                            // onChanged: (v) {
                            //   final bloc = context.read<DialogsBloc>();
                            //   bloc.add(
                            //     DialogsEvent.fetch(
                            //         ownProfileId: state.ownProfileId!,
                            //         search: v),
                            //   );
                            // },
                            cursorColor: AppColors.blue2D9CDB,
                            controller: _controller,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 5.h,
                              ),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              fillColor: AppColors.grayF2F4F5,
                              filled: true,
                              hintText: 'Поиск по сообщениям',
                              hintStyle: TextStyle(
                                color: AppColors.gray828282,
                                fontSize: 16.h,
                                fontFamily: "GilroyRegular",
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Container(
                                margin: EdgeInsets.symmetric(vertical: 10.h),
                                child: SvgPicture.asset(
                                  'assets/images/search.svg',
                                  color: showCross
                                      ? Colors.black
                                      : AppColors.gray828282,
                                ),
                              ),
                              prefixIconConstraints: BoxConstraints(
                                minWidth: 36.h,
                                minHeight: 36.h,
                              ),
                              suffixIcon: showCross
                                  ? IconButton(
                                      splashRadius: 1,
                                      padding: const EdgeInsets.all(0),
                                      onPressed: () {
                                        setState(() => _controller.clear());
                                        final bloc = context
                                            .read<DialogsBloc>();
                                        bloc.add(
                                          DialogsEvent.fetch(
                                            ownProfileId: state.ownProfileId!,
                                          ),
                                        );
                                      },
                                      icon: Icon(
                                        Icons.close,
                                        size: 16.r,
                                        color: Colors.black,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        GestureDetector(
                          onTap: () => context.pushRoute(
                            const CreateSupportRequestRoute(),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 8.h,
                              horizontal: 15.w,
                            ),
                            decoration: BoxDecoration(
                              color: isSeller
                                  ? AppColors.blueEAF5FB
                                  : AppColors.greenECFCE5,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  alignment: Alignment.center,
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSeller
                                        ? AppColors.blue2D9CDB
                                        : AppColors.green27AE60,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SvgPicture.asset(imgU),
                                ),
                                SizedBox(width: 16.5.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Поддержка Umit',
                                      style: TextStyle(
                                        color: AppColors.black333333,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'GilroyMedium',
                                      ),
                                    ),
                                    Text(
                                      'Будем рады помочь',
                                      style: TextStyle(
                                        color: AppColors.gray828282,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        fontFamily: 'GilroyRegular',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Visibility(
                          visible: state.isError,
                          child: const Expanded(
                            child: Center(
                              child: Text(
                                'Ошибка загрузки',
                                style: TextStyle(
                                  color: AppColors.gray828282,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'GilroyRegular',
                                ),
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: state.isFetched && state.chats!.isEmpty,
                          child: const Expanded(
                            child: Center(
                              child: Text(
                                'Сообщений пока нет',
                                style: TextStyle(
                                  color: AppColors.gray828282,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'GilroyRegular',
                                ),
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: state.isFetched && state.chats!.isNotEmpty,
                          child: const Expanded(child: ListDialogs()),
                        ),
                        Visibility(
                          visible: state.isLoading,
                          child: const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
