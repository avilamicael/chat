<script setup>
import { computed, ref, watch } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  title: { type: String, required: true },
  hint: { type: String, default: '' },
  items: { type: Array, default: () => [] },
  selectedIds: { type: Array, default: () => [] },
  addPlaceholder: { type: String, default: '' },
  emptyLabel: { type: String, default: '' },
});

const emit = defineEmits(['add', 'remove']);

const selected = computed(() =>
  props.items.filter(i => props.selectedIds.includes(i.id))
);
const available = computed(() =>
  props.items.filter(i => !props.selectedIds.includes(i.id))
);
const addOptions = computed(() =>
  available.value.map(i => ({ value: i.id, label: i.name }))
);

const pickerValue = ref(null);

watch(pickerValue, id => {
  if (id) {
    emit('add', Number(id));
    pickerValue.value = null;
  }
});
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex flex-col gap-0.5">
      <h3 class="text-sm font-medium text-n-slate-12">{{ title }}</h3>
      <p v-if="hint" class="text-xs text-n-slate-10">{{ hint }}</p>
    </div>
    <div class="flex flex-wrap gap-2">
      <span
        v-for="item in selected"
        :key="item.id"
        class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs bg-n-alpha-2 text-n-slate-11 border border-n-weak"
      >
        {{ item.name }}
        <button
          class="text-n-slate-9 hover:text-n-slate-12"
          @click="$emit('remove', item.id)"
        >
          <Icon icon="i-lucide-x" class="size-3" />
        </button>
      </span>

      <ComboBox
        v-if="available.length"
        v-model="pickerValue"
        :options="addOptions"
        :placeholder="addPlaceholder"
        :search-placeholder="addPlaceholder"
      />
      <span v-else-if="!selected.length" class="text-xs text-n-slate-9 italic">
        {{ emptyLabel }}
      </span>
    </div>
  </div>
</template>
