package io.agora.scene.common.util.toast;

import android.annotation.SuppressLint;
import android.app.Application;
import android.content.Context;
import android.os.Looper;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.RestrictTo;

import java.lang.ref.SoftReference;

import io.agora.scene.common.R;
import io.agora.scene.common.util.KtExtendKt;


//@RestrictTo({RestrictTo.Scope.LIBRARY})
public final class InternalToast {

    public static final int COMMON = 0;
    public static final int TIPS = 1;
    public static final int ERROR = 2;
    public static final int NEW_COMMON = 3;
    public static final int NEW_TIPS = 4;

    @SuppressLint("StaticFieldLeak")
    private static Application mApp;

    public static void init(@NonNull final Application app) {
        if (mApp == null) {
            mApp = app;
        }
    }

    public static Application getApp() {
        return mApp;
    }


    private InternalToast() {
        throw new UnsupportedOperationException("u can't instantiate me...");
    }

    private static void checkContext() {
        if (mApp == null) {
            throw new NullPointerException("ToastUtils context is not null，please first init");
        }
    }

    public static void show(CharSequence notice, int toastType, int duration) {
        checkMainThread();
        checkContext();
        if (TextUtils.isEmpty(notice)) {
            return;
        }
        new Builder(mApp)
                .setDuration(duration)
                .setGravity(Gravity.BOTTOM)
                .setOffset((int) KtExtendKt.getDp(200))
                .setToastTYpe(toastType)
                .setTitle(notice)
                .build()
                .show();
    }

    public static void show(CharSequence notice, int toastType, int duration, int gravity, int offsetY) {
        checkMainThread();
        checkContext();
        if (TextUtils.isEmpty(notice)) {
            return;
        }
        new Builder(mApp)
                .setDuration(duration)
                .setGravity(gravity)
                .setOffset(offsetY)
                .setToastTYpe(toastType)
                .setTitle(notice)
                .build()
                .show();
    }


    public static final class Builder {

        private final Context context;
        private CharSequence title;
        private int gravity = Gravity.TOP;
        private int yOffset;
        private int duration = Toast.LENGTH_SHORT;
        private int toastType;

        public Builder(Context context) {
            this.context = context;
        }

        public Builder setTitle(CharSequence title) {
            this.title = title;
            return this;
        }

        public Builder setToastTYpe(int toastType) {
            this.toastType = toastType;
            return this;
        }

        public Builder setGravity(int gravity) {
            this.gravity = gravity;
            return this;
        }

        public Builder setOffset(int yOffset) {
            this.yOffset = yOffset;
            return this;
        }

        public Builder setDuration(int duration) {
            this.duration = duration;
            return this;
        }

        private SoftReference<Toast> mToast;

        public Toast build() {
            if (!checkNull(mToast)) {
                mToast.get().cancel();
            }
            Toast toast = new Toast(context);

            View rootView;
            if (toastType == NEW_COMMON || toastType == NEW_TIPS) {
                rootView = LayoutInflater.from(context).inflate(R.layout.common_new_toast_view, null);
                TextView textView = rootView.findViewById(R.id.tvContent);
                ImageView imageView = rootView.findViewById(R.id.ivToast);

                textView.setText(title);
                if (toastType == NEW_COMMON) {
                    imageView.setVisibility(View.GONE);
                } else {
                    imageView.setVisibility(View.VISIBLE);
                }

            } else {
                rootView = LayoutInflater.from(context).inflate(R.layout.common_toast_view, null);
                TextView textView = rootView.findViewById(R.id.tvContent);
                ImageView imageView = rootView.findViewById(R.id.ivToast);

                textView.setText(title);
                if (toastType == COMMON) {
                    imageView.setVisibility(View.GONE);
                } else {
                    imageView.setVisibility(View.VISIBLE);
                    if (toastType == TIPS) {
                        imageView.setImageResource(R.drawable.toast_icon_right);
                    } else {
                        imageView.setImageResource(R.drawable.toast_icon_wrong);
                    }
                }

            }
            toast.setView(rootView);
            toast.setGravity(gravity, 0, yOffset);
            toast.setDuration(duration);
            mToast = new SoftReference<>(toast);
            return toast;
        }

        public void updateNotice(String text) {
            if (mToast == null) return;
            Toast toast = mToast.get();
            if (toast == null) return;
            View view = toast.getView();
            if (view == null) return;
            TextView textView = view.findViewById(R.id.tvContent);
            if (textView == null) return;
            textView.setText(text);
        }
    }


    private static boolean checkNull(SoftReference softReference) {
        return softReference == null || softReference.get() == null;
    }

    public static void checkMainThread() {
        if (!isMainThread()) {
            throw new IllegalStateException("Please do not perform popup operations in a work thread");
        }
    }

    private static boolean isMainThread() {
        return Looper.getMainLooper() == Looper.myLooper();
    }
}
